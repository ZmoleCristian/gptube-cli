#!/bin/bash
#GPTube.sh - Download YouTube subtitle and have them summarized by GPT-3.5 turbo
#Author: https://github.com/tragdate
#Version: 0.1
#License: GPL v3.0
#Usage: ./gptube.sh -u <YouTube URL> -l <captions language: default en (optional)> -k <GPT-3 API key> -d for debug mode (optional)

function main() {
  get_args "$@"
  check_config
  config
  read_config_file
  get_video_data
  check_captions
  download_transcript
  use_whisper
  send_to_gpt3
  cleanup
  write_summary
  print_response

}
usage() {
  echo "
  GPTube is command line tool that uses GPT-3 to summarize YouTube videos.
  Usage: gptube.sh -u "YouTube URL" 
  -d for debug mode (optional) 
  -c to configure settings (optional)"
}
function check_config() {
  #check if a config.json file exists in the ~/.config/gptube folder if not create it
  home_dir=$(echo $HOME)
  config_dir="$home_dir/.config/gptube"
  config_file="$config_dir/config.json"
  if [ ! -d "$config_dir" ]; then
    mkdir -p $config_dir
  fi
  if [ ! -f "$config_file" ]; then
    touch $config_file
  fi
  #check if the config file is empty
  if [ ! -s "$config_file" ]; then
    #write a json format settings file
    echo '{"api_key":"", "sub_lang":"", "custom_prompt":"Summerize video transcript", "allow_whisper":""}' >>$config_file
  fi
  #parse the config_file json to check if api_key value is empty
  api_key=$(jq -r '.api_key' $config_file)
  #if  empty ask the user to add it
  if [ -z "$api_key" ]; then
    #ask tue user for an api key
    echo "Api key is empty please specify the key and press [ENTER]:"
    read api_key
    #write the api key to the config file
    jq --arg api_key "$api_key" '.api_key = ($api_key)' $config_file >tmp.json && mv tmp.json $config_file
  fi
  #parse the config_file json to check if sub_lang value is empty
  sub_lang=$(jq -r '.sub_lang' $config_file)
  #if  empty ask the user to add it
  if [ -z "$sub_lang" ]; then
    echo "Subtitles language is empty please specify the language (example: en) and press [ENTER]:"
    read sub_lang
    #write the api key to the config file
    jq --arg sub_lang "$sub_lang" '.sub_lang = ($sub_lang)' $config_file >tmp.json && mv tmp.json $config_file
  fi

  #parse the config_file json to check if custom_prompt value is empty
  custom_prompt=$(jq -r '.custom_prompt' $config_file)
  #if  empty ask the user to add it
  if [ -z "$custom_prompt" ]; then
    echo "Enter a customized prompt for other use cases (example: Compliment the author of the video) [ENTER]:"
    read custom_prompt
    #write the api key to the config file
    jq --arg custom_prompt "$custom_prompt" '.custom_prompt = ($custom_prompt)' $config_file >tmp.json && mv tmp.json $config_file
  fi

  #parse the config_file json to check if allow_whisper value is empty
  allow_whisper=$(jq -r '.allow_whisper' $config_file)
  #if  empty ask the user to add it
  if [ -z "$allow_whisper" ]; then
    echo "Allow whisper is empty please specify true or false [ENTER]:"
    read allow_whisper
    #write the api key to the config file
    if [ $allow_whisper != "true" ] && [ $allow_whisper != "false" ]; then
      echo "Error: allow whisper must be true or false"
      echo "Exiting..."
      exit 1
    fi
    jq --arg allow_whisper "$allow_whisper" '.allow_whisper = ($allow_whisper)' $config_file >tmp.json && mv tmp.json $config_file
  fi

}
function read_config_file() {
  #read all values from the config file into variables
  api_key=$(jq -r '.api_key' $config_file)
  sub_lang=$(jq -r '.sub_lang' $config_file)
  custom_prompt=$(jq -r '.custom_prompt' $config_file)
  allow_whisper=$(jq -r '.allow_whisper' $config_file)
}

#get command line arguments -u for url -l for language (default en) -k for API key

function get_args() {
  while getopts u:dc option; do
    case "${option}" in

    u) url=${OPTARG} ;;
    d) debug=debug ;;
    c) config=true ;;
    esac
  done
  #check if url is empty
  if [[ -z "$url" && -z "$config" ]]; then
    usage
    exit 1
  fi
}

function config() {
  #if config is true then run the config function
  if [ "$config" = "true" ]; then
    #ask the user if he wants to change they api key
    echo "Do you want to change the API key? (y/n)"
    read change_api_key
    #if answer yes then ask for the new api key
    if [ $change_api_key = "y" ]; then
      #ask user for the new api key
      echo "Please enter the new API key and press [ENTER]:"
      read api_key
      #write the api key to the config file
      jq --arg api_key "$api_key" '.api_key = ($api_key)' $config_file >tmp.json && mv tmp.json $config_file
    fi
    #ask the user if he wants to change they subtitles language
    echo "Do you want to change the subtitles language? (y/n)"
    read change_sub_lang
    #if answer yes then ask for the new subtitles language
    if [ $change_sub_lang = "y" ]; then
      #ask user for the new subtitles language
      echo "Please enter the new subtitles language (example: en) and press [ENTER]:"
      read sub_lang
      #write the subtitles language to the config file
      jq --arg sub_lang "$sub_lang" '.sub_lang = ($sub_lang)' $config_file >tmp.json && mv tmp.json $config_file
    fi
    #ask the user if he wants to change they custom prompt
    echo "Do you want to change the custom prompt? (y/n)"
    read change_custom_prompt
    #if answer yes then ask for the new custom prompt
    if [ $change_custom_prompt = "y" ]; then
      #ask user for the new custom prompt
      echo "Enter a customized prompt for other use cases (example: Compliment the author of the video) [ENTER]:"
      read custom_prompt
      #write the custom prompt to the config file
      jq --arg custom_prompt "$custom_prompt" '.custom_prompt = ($custom_prompt)' $config_file >tmp.json && mv tmp.json $config_file
    fi
    #ask the user if he wants to change they allow whisper
    echo "Do you want to change the allow whisper? (y/n)"
    read change_allow_whisper
    #if answer yes then ask for the new allow whisper
    if [ $change_allow_whisper = "y" ]; then
      #ask user for the new allow whisper
      echo "Please enter the new allow whisper (true / false) and press [ENTER]:"
      read allow_whisper
      #write the allow whisper to the config file
      if [ $allow_whisper != "true" ] && [ $allow_whisper != "false" ]; then
        echo "Error: allow whisper must be true or false"
        echo "Exiting..."
        exit 1
      fi
      jq --arg allow_whisper "$allow_whisper" '.allow_whisper = ($allow_whisper)' $config_file >tmp.json && mv tmp.json $config_file
    fi
    #exit the script
    echo "Your config file has been updated"
    echo "Exiting..."
    exit 0

  fi

}

function get_video_data() {
  #get youtube video id and title into varible video_data then split it into video_id and video_title
  if [ "$debug" = "debug" ]; then
    echo "Getting video data..."
  fi

  video_data=$(yt-dlp --get-id --get-title $url >tmp.data)
  video_id=$(cat tmp.data | sed -n 2p)
  video_title=$(cat tmp.data | sed -n '1{s/[^a-zA-Z0-9]/ /g;p}')

  if [ "$debug" = "debug" ]; then
    echo "Video selected $video_title with id $video_id and language ($sub_lang)"
  fi
}

function check_captions() {
  #check if the video has captions in the selected language
  if [ "$debug" = "debug" ]; then
    echo "Checking if the video has captions in the selected language..."

  fi
  #check if the video has captions in the selected language
  sub_result=$(yt-dlp -o tmp --write-auto-sub --sub-lang $sub_lang --skip-download $url)
  #check if the video has captions in the selected language
  if [[ $sub_result != *"There's no subtitles"* ]]; then
    if [ "$debug" = "debug" ]; then
      echo "Captions found in the selected language..."

    fi
    captions=true
  else
    if [ "$debug" = "debug" ]; then
      echo "Captions not found in the selected language..."
      #if whisper if disabled exit
      if [ "$allow_whisper" = "false" ]; then
        echo "You didn't allow whisper in config, use ./gptube -c to change the config "
        exit 1
      fi
    fi
    captions=false
  fi
}

function download_transcript() {
  #if captions = true
  if [ "$captions" = true ]; then
    if [ "$debug" = "debug" ]; then
      echo "Downloading transcript..."
      yt-dlp -o tmp --write-auto-sub --sub-lang $sub_lang --skip-download $url
    else
      yt-dlp -o tmp --write-auto-sub --sub-lang $sub_lang --skip-download $url &>/dev/null
    fi
    #create a text file with the video title and id and the transcript
    text_file_name="Transcript-${video_title}.${video_id}.${sub_lang}.transcript"
    if [ "$debug" = "debug" ]; then
      echo "Extracting text from transcript..."

    fi
    vtt_file_name=tmp.$sub_lang.vtt
    sed -i '1d' $vtt_file_name
    prompt=$(cat $vtt_file_name | grep : -v | awk '!seen[$0]++' | tr '\n' ',')
    if [ "$debug" = "debug" ]; then
      echo "Writing transcript to file... $text_file_name"

    fi
    echo $prompt >"$text_file_name"
    if [ "$debug" = "debug" ]; then
      echo "Removing temporary files..."
    fi
    rm $vtt_file_name
  fi

}

function use_whisper() {
  #if captions are not found in the selected language and allow_whisper is true
  if [ "$captions" = false ] && [ "$allow_whisper" = true ]; then
    if [ "$debug" = "debug" ]; then
      echo "Captions not found in the selected language, using whisper api..."
    fi
    #get the transcript from whisper api
    if [ "$debug" = "debug" ]; then
      echo "Getting transcript from whisper api..."
    fi
    #download mp3 wihth yt-dlp
    if [ "$debug" = "debug" ]; then
      echo "Downloading mp3..."
    fi
    #if debug mode is on
    if [ "$debug" = "debug" ]; then
      yt-dlp -o audio.mp3 -x --audio-format mp3 $url
    else
      yt-dlp -o audio.mp3 -x --audio-format mp3 $url &>/dev/null
    fi

    whisper_response=$(curl --request POST \
      -s \
      --url https://api.openai.com/v1/audio/transcriptions \
      --header "Authorization: Bearer "$api_key"" \
      --header 'Content-Type: multipart/form-data' \
      --form file=@audio.mp3 \
      --form model=whisper-1 | jq -r '.text')
    echo $whisper_response >"Transcript-${video_title}-${video_id}.transcript"
    prompt=$(echo $whisper_response | tr '\n' ',' | tr '"' '`')

  fi
  if [ "$captions" = false ] && [ "$allow_whisper" = false ]; then
    echo "You didn't allow whisper in config, use ./gptube -c to change the config "
    exit 1
  fi
}

function send_to_gpt3() {
  #if debug mode is on

  if [ "$debug" = "debug" ]; then
    echo "Sending transcript to GPT-3..."
  fi
  if [ "$debug" = "debug" ]; then
    response=$(curl https://api.openai.com/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer "$api_key"" \
      -d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "'"$custom_prompt"': '"$prompt"'"}]
}')

  else
    response=$(curl https://api.openai.com/v1/chat/completions \
      -s \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer "$api_key"" \
      -d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "'"$custom_prompt"': '"$prompt"'"}]
}' | jq -r '.choices[].message.content')

  fi

}
function write_summary() {
  if [ "$debug" = "debug" ]; then
    echo "Writing result to file..."

  fi
  echo $response >"Result-${video_title}.${video_id}.${sub_lang}.summary"
}
function print_response() {
  if [ "$debug" = "debug" ]; then
    echo "Response:"
  fi
  echo $response
}
function cleanup() {
  if [ "$debug" = "debug" ]; then
    echo "Cleaning up..."
  fi
  rm audio.mp3
  #remove tmp files
  rm *"["$video_id"]"*
  rm tmp*
}

main "$@"
