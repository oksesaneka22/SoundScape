import os
import json
import requests

# SonarQube API Token
SONARQUBE_TOKEN = os.getenv('SONARQUBE_TOKEN')
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
GITHUB_REPO = "Kholod13/SoundScape"  # Format: owner/repo
SONARQUBE_URL = "http://192.168.0.122:9000"
PROJECT_KEY = "Soundscape-back"

if not SONARQUBE_TOKEN or not GITHUB_TOKEN:
    print("Error: Missing SONARQUBE_TOKEN or GITHUB_TOKEN environment variable.")
    exit(1)

# Fetch SonarQube Issues
sonar_api_url = f"{SONARQUBE_URL}/api/issues/search?componentKeys={PROJECT_KEY}&resolved=false"
response = requests.get(sonar_api_url, auth=(SONARQUBE_TOKEN, ""))

# Check if the response is successful
if response.status_code != 200:
    print(f"Error: Failed to fetch SonarQube issues. Status code: {response.status_code}")
    print(f"Response content: {response.text}")
    exit(1)

try:
    issues = response.json().get("issues", [])
except json.JSONDecodeError as e:
    print(f"Error: Failed to parse JSON response. {e}")
    print(f"Response content: {response.text}")
    exit(1)

if not issues:
    print("No issues found in SonarQube.")
    exit()

# Format Issues
issue_body = "### SonarQube Analysis Report\n\n"
for issue in issues[:15]:  # Limit to 15 issues to avoid too much data
    issue_body += f"- **{issue.get('message', 'No Message')}**\n"
    issue_body += f"  - Severity: {issue.get('severity', 'Unknown')}\n"
    issue_body += f"  - Component: {issue.get('component', 'Unknown')}\n"
    issue_body += f"  - Line: {issue.get('line', 'N/A')}\n"
    issue_body += f"  - [View in SonarQube](http://sonar.mystat.pp.ua/issues?id={PROJECT_KEY}&open={issue.get('key')})\n\n"

# Create GitHub Issue
github_api_url = f"https://api.github.com/repos/{GITHUB_REPO}/issues"
headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
payload = {"title": "SonarQube Issues Report", "body": issue_body}

github_response = requests.post(github_api_url, json=payload, headers=headers)

if github_response.status_code == 201:
    print("GitHub issue created successfully!")
    print("Issue URL:", github_response.json().get("html_url"))
else:
    print("Failed to create GitHub issue:", github_response.text)
