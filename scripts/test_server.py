import requests
import json
import time
import sys

def wait_for_server(url, timeout=300):
    start_time = time.time()
    print(f"Waiting for server at {url}...")
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{url}/v1/models")
            if response.status_code == 200:
                print("Server is ready!")
                return True
        except requests.exceptions.ConnectionError:
            pass
        time.sleep(5)
    print("Timeout waiting for server.")
    return False

def test_chat(url):
    headers = {"Content-Type": "application/json"}
    data = {
        "model": "qwen3.6-35b-a3b-iq4xs",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello! How are you today?"}
        ],
        "max_tokens": 50
    }
    
    print("Sending chat request...")
    try:
        response = requests.post(f"{url}/v1/chat/completions", headers=headers, data=json.dumps(data))
        if response.status_code == 200:
            result = response.json()
            print("Response from model:")
            print(result['choices'][0]['message']['content'])
        else:
            print(f"Error: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == "__main__":
    server_url = "http://localhost:9998"
    if wait_for_server(server_url):
        test_chat(server_url)
    else:
        sys.exit(1)
