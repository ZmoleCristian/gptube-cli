# GPTube CLI

GPTube CLI is a command-line tool for generating video summaries based on transcripts from YouTube videos. The program extracts the video's closed captions, processes them using GPT-3 from OpenAI, and creates a summary of the video.

## 🚀 Features
- ⬇️ Retrieves video data and captions from YouTube videos
- 🤖 Utilizes OpenAI's GPT-3 for generating video summaries
- ✍️ Offers post-processing functionality
- 📃 Supports reading a list of video URLs for processing

##  📝 Requirements
- 🦀 Rust 1.56.0 or later
- 📦 Cargo
- 🧠 Get an API Key from [OpenAI](https://platform.openai.com/) 
- 📺 Latest [yt-dlp](https://github.com/yt-dlp/yt-dlp) binary

<br>

## 💾 Installation

### 🪄 One command install 
> Paste this in your command line to install both precompiled binaries from github straight into your /usr/local/bin/

```shell
sudo wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp && sudo chmod a+rx /usr/local/bin/yt-dlp && sudo wget https://github.com/tragdate/gptube-cli/releases/latest/download/gptube-cli -O /usr/local/bin/gptube-cli && sudo chmod a+rx /usr/local/bin/gptube-cli
```
#### OR

### 🛠Installationl from source
You can compile the program from source using `cargo`
```command-line
git clone https://github.com/tragdate/gptube-cli
cd gptube-cli
cargo build --release
sudo cp target/release/gptube-cli /usr/local/bin/
```

## 📍 Usage
```plaintext
gptube-cli [FLAGS] [OPTIONS]
```

### 🚩 Flags

- `-d`, `--debug`
  * Prints additional debugging information
- `-p`, `--post_process`
  * Post-processing functionality. Prompts for input on how to further process the generated summary
- `-c`, `--config`
  * Create a configuration file if not already available

### ⚙ Options

- `-u`, `--url`
  * Provide a single YouTube video URL. Conflicts with `--url_list` and `--config`
- `-l`, `--url_list`
  * Provide a path to a file containing a list of YouTube video URLs separated by commas.

#### List example
`cat video-list.txt`
```
https://www.youtube.com/watch?v=VIDEO_ID,
https://www.youtube.com/watch?v=VIDEO_ID,
https://www.youtube.com/watch?v=VIDEO_ID
```
### 📚 Examples

Create a configuration file, or update the existing one:
```plaintext
gptube-cli --config
```

Generate a summary for a single video:
```plaintext
gptube-cli -u 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Generate summaries for multiple videos from a list in a file:
```plaintext
gptube-cli -l 'video-list.txt'
```

Enable post-processing for generated summaries:
```plaintext
gptube-cli -u 'https://www.youtube.com/watch?v=VIDEO_ID' -p
```

Enable debug mode:
```plaintext
gptube-cli -u 'https://www.youtube.com/watch?v=VIDEO_ID' -d
```

## 🥷 Author
[Trag Date](https://tragdate.ninja)

## License
This project is licensed under the [GPLv3](https://choosealicense.com/licenses/gpl-3.0/)
