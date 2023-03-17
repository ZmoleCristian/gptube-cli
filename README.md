# GPTube-cli

GPTube-cli is a command-line tool that by default summarizes YouTube videos using the OpenAI GPT-3.5-turbo language model. This program is designed to simplify the process of creating summaries for videos by automating the transcription process and then using GPT-3.5-turbo to generate a summary.

You can also use it to make a compliment for the video author, criticize the video, or whatever you set the custom prompt to be.
<br><br>
## Installation
To use GPTube, clone the repository and run the following command in the project directory:

```bash
git clone https://github.com/tragdate/gptube-cli.git
cd gptube-cli
sudo make install
```

This will install the necessary dependencies and create gptube executable in `/usr/local/bin`, allowing you to run the program from anywhere.
<br><br>

## Usage
To summarize a video using GPTube, run the following command:

 
```bash
gptube -u "YouTube URL"
```
`It works with any other video url that yt-dlp supports`

This will download the video, generate a transcript, summarize the transcript using GPT-3, and print the summary to the console to the path that you run it in.
<br><br>

## Whisper API
If the video does not have subtitles in the given language at configuration, GPTube-cli will use the whipser api to generate subtitles. 

This feature can be disabled by setting the `allow_whisper` option to `false` in the configuration file when using `-c` option.

 `Notice that the whisper api is more expensive than the usual request, so you need to pay for it if you want to use it.`
<br><br>

## Options
GPTube supports the following options:

* `-d` :  Enable debug mode (prints additional information to the console)
* `-c` :  Configure GPTube-cli settings
* `-u` :  Specify YouTube URL
<br><br>

## Configuration
GPTube can be configured by running the following command:

```bash 
gptube -c
```
This will prompt you to enter your 
* API key
* subtitles language
* custom prompt
* allow whisper setting

These settings will be saved to a JSON file located at `$HOME/.config/gptube/config.json.`
<br><br>
## License
This project is licensed under the [GPLv3](https://choosealicense.com/licenses/gpl-3.0/)
