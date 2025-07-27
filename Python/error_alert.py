import requests
import subprocess
import os

# Telegram bot token and chat ID
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')

def send_telegram_message(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': message
    }
    response = requests.post(url, data=payload)
    if response.status_code != 200:
        raise Exception(f"Error sending message: {response.text}")

def main():
    message = f"❌Deployment FAILED. http://jk.mystat.pp.ua/job/Front-trigger/{os.getenv('BUILD_NUMBER')}/console"
    send_telegram_message(message)

if __name__ == "__main__":
    main()

