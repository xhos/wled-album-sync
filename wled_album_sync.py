import os
import sys
import time
import base64
import requests
from io import BytesIO
from PIL import Image
from colorthief import ColorThief
import numpy as np
from flask import Flask
from threading import Thread

def load_env(var):
    val = os.getenv(var)
    if not val:
        print(f"missing env var {var}")
        sys.exit(1)
    return val

config = {
    'wled_url': load_env('WLED_URL'),
    'ha_url': os.getenv('HA_URL'),
    'ha_token': os.getenv('HA_TOKEN'),
    'ha_entity': os.getenv('HA_ENTITY'),
    'spotify_client_id': os.getenv('SPOTIFY_CLIENT_ID'),
    'spotify_client_secret': os.getenv('SPOTIFY_CLIENT_SECRET'),
    'spotify_refresh_token': os.getenv('SPOTIFY_REFRESH_TOKEN'),
    'http_port': int(os.getenv('HTTP_PORT', '8080')),
}

token_state = {'token': None, 'expires_at': 0}
sync_state = {'enabled': True}

app = Flask(__name__)

@app.route('/toggle', methods=['POST'])
def toggle():
    sync_state['enabled'] = not sync_state['enabled']
    status = 'enabled' if sync_state['enabled'] else 'disabled'
    return {'status': status}, 200

@app.route('/status')
def status():
    return {'enabled': sync_state['enabled']}, 200

def get_access_token():
    auth = base64.b64encode(f"{config['spotify_client_id']}:{config['spotify_client_secret']}".encode()).decode()
    resp = requests.post('https://accounts.spotify.com/api/token',
                        headers={'Authorization': f'Basic {auth}'},
                        data={'grant_type': 'refresh_token', 'refresh_token': config['spotify_refresh_token']})
    return resp.json()['access_token']

def ensure_token():
    now = time.time() * 1000
    if token_state['expires_at'] < now:
        token_state['token'] = get_access_token()
        token_state['expires_at'] = now + (55 * 60 * 1000)
    return token_state['token']

def get_spotify_track():
    if not config['spotify_refresh_token']:
        return None
    token = ensure_token()
    resp = requests.get('https://api.spotify.com/v1/me/player/currently-playing',
                       headers={'Authorization': f'Bearer {token}'})
    if resp.status_code != 200 or not resp.content:
        return None
    data = resp.json()
    track = data.get('item')
    if not track:
        return None
    return {
        'name': track['name'],
        'artist': track['artists'][0]['name'],
        'art': track['album']['images'][0]['url'],
        'id': track['id'],
    }

def get_ha_track():
    if not config['ha_token'] or not config['ha_entity']:
        return None
    resp = requests.get(f"{config['ha_url']}/api/states/{config['ha_entity']}",
                       headers={'Authorization': f"Bearer {config['ha_token']}"})
    if resp.status_code != 200:
        return None
    data = resp.json()
    if data.get('state') != 'playing':
        return None
    attrs = data.get('attributes', {})
    pic = attrs.get('entity_picture')
    if not pic:
        return None
    art_url = f"{config['ha_url']}{pic}" if pic.startswith('/') else pic
    return {
        'name': attrs.get('media_title', 'Unknown'),
        'artist': attrs.get('media_artist', 'Unknown'),
        'art': art_url,
        'id': f"ha_{attrs.get('media_title')}_{attrs.get('media_artist')}",
        'auth': config['ha_token'],
    }

def download_art(url, token=None):
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    resp = requests.get(url, headers=headers)
    return Image.open(BytesIO(resp.content))

def brightness(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

def saturation(c):
    mx, mn = max(c), min(c)
    return 0 if mx == 0 else (mx - mn) / mx

def normalize(c, target=140):
    b = brightness(c)
    if b == 0:
        return c
    s = target / b
    return tuple(min(255, int(x * s)) for x in c)

def distance(c1, c2):
    return sum((a - b) ** 2 for a, b in zip(c1, c2)) ** 0.5

def frequency(img, color, tol=30):
    small = img.resize((100, 100))
    if small.mode != 'RGB':
        small = small.convert('RGB')
    pixels = np.array(small)
    diff = np.abs(pixels - color)
    matches = np.all(diff < tol, axis=2)
    return np.sum(matches) / 10000

def extract_colors(img, n=5):
    buf = BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    palette = ColorThief(buf).get_palette(color_count=15, quality=1)
    candidates = []
    for c in palette:
        s = saturation(c)
        b = brightness(c)
        f = frequency(img, c)
        if b < 20 or s < 0.25 or f < 0.02:
            continue
        score = f * 2.0 + s * 0.5
        candidates.append((c, score))
    candidates.sort(key=lambda x: x[1], reverse=True)
    if not candidates:
        return [(80, 80, 80), (180, 180, 180), (80, 80, 80)]
    filtered = [candidates[0][0]]
    for c, _ in candidates[1:]:
        if len(filtered) >= n:
            break
        if min(distance(c, fc) for fc in filtered) > 100:
            filtered.append(c)
    return [normalize(c, 140) for c in filtered]

def apply_wled(colors):
    payload = {
        'on': True,
        'bri': 200,
        'transition': 20,
        'seg': [{
            'col': [[c[0], c[1], c[2]] for c in colors[:3]],
            'fx': 46,
            'sx': 128,
            'ix': 200,
            'pal': 0
        }]
    }
    resp = requests.post(f"{config['wled_url']}/json/state", json=payload)
    return resp.status_code == 200

def sync_loop():
    last_id = None
    while True:
        if sync_state['enabled']:
            track = get_ha_track() or get_spotify_track()
            if track and track['id'] != last_id:
                print(f"{track['name']} - {track['artist']}")
                img = download_art(track['art'], track.get('auth'))
                colors = extract_colors(img)
                apply_wled(colors)
                last_id = track['id']
        time.sleep(5)

def main():
    import logging
    logging.getLogger('werkzeug').setLevel(logging.ERROR)
    Thread(target=sync_loop, daemon=True).start()
    app.run(host='0.0.0.0', port=config['http_port'], debug=False, use_reloader=False)

if __name__ == '__main__':
    main()
