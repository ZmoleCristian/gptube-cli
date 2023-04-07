use std::process::Command;
use std::fs;
use serde_json::Value;
use serde_json::json;
use reqwest::Client;
use structopt::StructOpt;
use std::error::Error;
use serde::{Serialize, Deserialize};
use std::time::Instant;
use futures::future::join_all;
use tokio::fs::File;
use tokio::io::AsyncWriteExt;
use tokio::io::BufReader;
use tokio_util::codec::{BytesCodec, FramedRead};
use futures::StreamExt;


#[derive(StructOpt, Debug)]
#[structopt(name = "gptube")]
struct Opt {
    #[structopt(short = "u", long,conflicts_with = "config")]
    url: Option<String>,
    #[structopt(short = "l", long,conflicts_with = "url",conflicts_with = "config")]
    url_list: Option<String>,
    #[structopt(short = "d", long)]
    debug: bool,
    #[structopt(short, long,conflicts_with = "config", conflicts_with = "url_list")]
    post_process: bool,
    #[structopt(short, long)]
    config: bool,
}
#[derive(Debug, Serialize, Deserialize)]
struct Config {
    api_key: String,
    sub_lang: String,
    custom_prompt: String,
    allow_whisper: String,
}

async fn create_config(debug: bool) {
    if debug {
        println!("Creating configuration file...");
    }

    let home = std::env::var("HOME").expect("Failed to get home directory");
    let config_dir = format!("{}/.config/gptube-cli", home);
    let config_file_path = format!("{}/.config/gptube-cli/config.json", home);
    let config_file = fs::File::open(&config_file_path);

    fn read_input(prompt: &str) -> String {
        println!("{}", prompt);
        let mut input = String::new();
        std::io::stdin()
            .read_line(&mut input)
            .expect("Failed to read line");
        input.trim().to_string()
    }

    let api_key = read_input("Please enter your OpenAI API key: ");
    let sub_lang = read_input("Please enter the language code of the captions you want to use (Example: en, fr, es, etc.): ");
    let custom_prompt = read_input("Please enter the custom prompt you want to use (Example: Summarize this video, Criticize this video, etc.): ");
    let allow_whisper = read_input("Please enter if you want to allow whispers (true or false): ");

    let config = Config {
        api_key,
        sub_lang,
        custom_prompt,
        allow_whisper,
    };

    if debug {
        println!("Configuration data: {:?}", config);
        println!("Creating config file at: {}", config_file_path);
    }

    match config_file {
        Ok(_) => {
            if debug {
                println!("Updating existing configuration file");
            }
            let mut file = fs::OpenOptions::new()
                .write(true)
                .truncate(true)
                .open(&config_file_path)
                .expect("Failed to open config file");
            serde_json::to_writer(&mut file, &config).expect("Failed to write to config file");
        }
        Err(_) => {
            fs::create_dir_all(&config_dir).expect("Failed to create config directory");
            let mut file = fs::File::create(&config_file_path).expect("Failed to create config file");
            serde_json::to_writer(&mut file, &config).expect("Failed to write to config file");
        }
    }
}


async fn read_config(debug: bool) -> Result<Option<Config>, Box<dyn Error>> {
    if debug {
        println!("Reading configuration file...");
    }

    let home = std::env::var("HOME").expect("Failed to get home directory");
    let config_file_path = format!("{}/.config/gptube-cli/config.json", home);
    let config_file = File::open(&config_file_path).await;

    if debug {
        println!("Configuration file path: {}", config_file_path);
    }

    match config_file {
        Ok(file) => {
            let buf_reader = BufReader::new(file);
            let mut framed = FramedRead::new(buf_reader, BytesCodec::new());
            let buf = framed.next().await.ok_or("Failed to read file")??;
            let config: Config = serde_json::from_slice(&buf)?;
            if debug {
                println!("Config OK");
            }
            Ok(Some(config))
        }
        Err(_) => Ok(None),
    }
}


async fn get_video_data_and_transcript(url: &str, lang: &str, debug: bool) -> (String, String, String) {
    if debug {
        println!("Retrieving video data and transcript for URL: {}", url);
    }

    let start_time = Instant::now();

    let output = Command::new("yt-dlp")
        .arg("-o")
        .arg("%(title)s:::::%(id)s:::::.%(ext)s")
        .arg("--write-auto-sub")
        .arg("--sub-lang")
        .arg(lang)
        .arg("--skip-download")
        .arg(url)
        .output()
        .expect("Failed to get video data and transcript");

    let output_str = String::from_utf8_lossy(&output.stdout);

    let mut lines = output_str.lines();
    let file_name = lines.find(|line| line.contains("Destination:")).unwrap();
    let file_name = file_name.split("Destination: ").collect::<Vec<&str>>()[1];
    let file_split = file_name.split(":::::").collect::<Vec<&str>>();
    let video_title = file_split[0].to_string();
    let video_id = file_split[1].to_string();

  
    if output_str.contains("There's no subtitles") {
        return (video_title, video_id, String::new());
    }

    let vtt_content = fs::read_to_string(&file_name).expect("Failed to read VTT file");
    //delete file after read
    fs::remove_file(&file_name).expect("Failed to delete VTT file");
    let end_time = Instant::now();
    let elapsed_time = end_time - start_time;

    if debug {
        println!("Video data and transcript retrieved in {} seconds", elapsed_time.as_secs_f32());
        println!("Video selected {} with id {} and language {}", video_title, video_id, lang);
    }

    (video_title, video_id, vtt_content)
}


async fn parse_webvtt(vtt_file_content: &str, debug: bool) -> String {
    if debug {
        println!("Parsing WebVTT content...");
    }

    let mut cues = Vec::new();
    let lines = vtt_file_content.lines();

    let mut lines_iter = lines.into_iter();

    while let Some(line) = lines_iter.next() {
        if line.contains("-->") {
            if let Some(text) = lines_iter.next() {
                cues.push(text.to_string());
                
            }
        }
    }
    let mut result = String::new();
    for (i, line) in cues.join("\n").lines().enumerate() {
        if i % 2 == 0 {
            result.push_str(line);
            result.push('\n');
        }
    }
    result
}

async fn send_to_gpt3(api_key: &str,custom_prompt: &str, sub_text: &str, debug: bool) -> String {
    if debug {
        println!("Sending text to GPT-3...");
    }

    let client = Client::new();
    let request_body = json!({
        "model": "gpt-3.5-turbo",
        "messages": [{"role": "user", "content": format!("{}:{}",custom_prompt, sub_text)}]
    });

    let response = client.post("https://api.openai.com/v1/chat/completions")
        .header("Content-Type", "application/json")
        .header("Authorization", format!("Bearer {}", api_key))
        .json(&request_body)
        .send()
        .await
        .expect("Failed to send request to GPT-3");
    
    let response_text: Value = response.json().await.expect("Failed to parse GPT-3 response");
    if debug {
        println!("GPT-3 response: {:?}", response_text);
    }
    
    if response_text["error"].is_string() {
        println!("Error: {}", response_text["error"].as_str().unwrap());
    }
    let summary = response_text["choices"][0]["message"]["content"].as_str().unwrap_or("Failed to create transcript").to_string();
    //if response text has error, print it
  
    summary
}
// post processing function
async fn post_process(api_key: &str, summary: &str, debug: bool) -> String {
    if debug {
        println!("Post-processing summary...");
    }

    let opt = Opt::from_args();

    let mut current_summary = summary.to_string();
    loop {
        let mut post_process = String::new();
        println!("Do you want to post process the summary? (y/n)");
        std::io::stdin().read_line(&mut post_process).expect("Failed to read line");
        if post_process.trim() == "y" {
            let mut new_prompt = String::new();
            println!("Enter a new prompt");
            std::io::stdin().read_line(&mut new_prompt).expect("Failed to read line");
            let new_prompt = format!("{} {}", new_prompt.trim(), current_summary);
            current_summary = send_to_gpt3(api_key, &new_prompt, &current_summary, opt.debug).await;
            println!("Summary: {}", current_summary);
        } else {
            break;
        }
    }

    current_summary
}



async fn process_url(api_key: &str, custom_prompt: &str, sub_lang: &str, url: &str, debug: bool) {
    if debug {
        println!("Processing URL: {}", url);
    }

    let opt = Opt::from_args();
    let (video_title, video_id, vtt_file_content) = get_video_data_and_transcript(&url, &sub_lang, debug).await;
    if opt.url_list.is_some() {
        println!("Processing Video: {} with id {} and language {}", video_title, video_id, sub_lang);
    }
    let sub_text = parse_webvtt(&vtt_file_content, debug).await;
    let mut summary = send_to_gpt3(&api_key, &custom_prompt, &sub_text, debug).await;
    let summary_file_name = format!("Result-{}.{}.{}.summary", video_title, video_id, &sub_lang);
    let mut file = File::create(&summary_file_name).await.expect("Failed to create summary file");
    println!("Result: {}", summary);
    if opt.url_list.is_some() {
        summary = format!("Result for {}:\n{}\n\n", video_title, summary);
    }else{
        summary = format!("Result for {}:\n{}\n", video_title, summary);
    }
    if opt.post_process {
        summary = post_process(&api_key, &summary, debug).await;
    }
    file.write_all(summary.as_bytes()).await.expect("Failed to write summary to file");
}

#[tokio::main]
async fn main() {
    let opt = Opt::from_args();
    if opt.config {
        create_config(opt.debug).await;
        return;
    }
    let config = read_config(opt.debug).await;

    if let Ok(Some(config)) = config {
        if let Some(url) = opt.url {
            process_url(&config.api_key, &config.custom_prompt, &config.sub_lang, &url, opt.debug).await;
        } else if let Some(url_list) = opt.url_list {
            //read url list from file
            let url_list = fs::read_to_string(url_list).expect("Failed to read url list file");
            let urls = url_list.split(',').map(|s| s.to_string()).collect::<Vec<String>>();
            let tasks = urls.into_iter().map(|url| {
                let api_key = config.api_key.clone();
                let custom_prompt = config.custom_prompt.clone();
                let sub_lang = config.sub_lang.clone();
                let debug = opt.debug;
                tokio::spawn(async move {
                    process_url(&api_key, &custom_prompt, &sub_lang, &url, debug).await;
                })
            }).collect::<Vec<_>>();
            
            join_all(tasks).await;
        }
    } else {
        println!("No configuration file found.");
        create_config(opt.debug).await;
    }
}

