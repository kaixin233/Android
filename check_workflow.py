import json, urllib.request, ssl, sys

# Try to get logs via the redirect URL
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

run_id = '30884459988'
# First get the job ID
url = f'https://api.github.com/repos/kaixin233/Android/actions/runs/{run_id}/jobs'
req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'Python'})
try:
    with urllib.request.urlopen(req, context=ctx) as resp:
        data = json.loads(resp.read())
    jobs = data.get('jobs', [])
    if jobs:
        job_id = jobs[0]['id']
        print(f"Job ID: {job_id}")
        print(f"Job URL: {jobs[0]['html_url']}")
        
        # Get the steps
        for step in jobs[0].get('steps', []):
            name = step.get('name', '')
            status = step.get('status', '')
            conclusion = step.get('conclusion', '')
            print(f"  Step: {name} | {status}/{conclusion}")
except Exception as e:
    print(f"Error: {e}")