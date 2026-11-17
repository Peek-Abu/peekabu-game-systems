"""Create a NEW Icey Labs (group 189923277) model asset from an FBX (Open Cloud POST), then poll the operation.
Never VentureMMO. The key is read from ICEY_LABS_OPEN_CLOUD_KEY (env or the Windows user registry) and never printed.
  python create_model.py <file.fbx> <displayName> <description>"""
import json, os, sys, time, uuid, urllib.request, urllib.error
path, name, desc = sys.argv[1], sys.argv[2], sys.argv[3]
CT = 'model/x-rbxm' if path.endswith('.rbxm') else 'model/fbx'
GROUP = 189923277
API = 'https://apis.roblox.com/assets/v1'
KEY = os.environ.get('ICEY_LABS_OPEN_CLOUD_KEY')
if not KEY and os.name == 'nt':
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as reg:
        KEY = winreg.QueryValueEx(reg, 'ICEY_LABS_OPEN_CLOUD_KEY')[0]
def req(method, url, data=None, headers=None):
    r = urllib.request.Request(url, data=data, method=method, headers={'x-api-key': KEY, **(headers or {})})
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, x.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors='replace')
b = uuid.uuid4().hex
meta = json.dumps(dict(assetType='Model', displayName=name, description=desc, creationContext=dict(creator=dict(groupId=GROUP))))
blob = open(path, 'rb').read()
body = (f'--{b}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n{meta}\r\n'
        f'--{b}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\nContent-Type: model/fbx\r\n\r\n').encode() + blob + f'\r\n--{b}--\r\n'.encode()
code, text = req('POST', f'{API}/assets', body, {'Content-Type': f'multipart/form-data; boundary={b}'})
print('POST', code, text[:300])
if code >= 300: sys.exit(1)
op = json.loads(text); p = op.get('path') or f"operations/{op.get('operationId')}"
for _ in range(60):
    code, text = req('GET', f'{API}/{p}')
    if code == 200 and json.loads(text).get('done'):
        print('DONE', text[:500]); break
    time.sleep(2)
else:
    print('NOT DONE', text[:300])
