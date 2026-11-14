#!/usr/bin/env python3
"""Vesper's music, ambience and sound effects with Stable Audio 3 Medium (text-to-audio, local GPU), as takes to
audition (WO-022). Ported from Fennwick 3D's tools/audio/stable_sfx.py; the requests are data/audio/sounds.json
(three prompts per sound, `takes` each, in sections: music, ambience, sfx).

    SA3=C:/dev/tools/stable-audio-3/.venv/Scripts/python.exe
    $SA3 tools/audio/stable_audio.py gen [name ...]     # the missing takes (one model load; resumes)
    $SA3 tools/audio/stable_audio.py page               # .audio/audition.html
    $SA3 tools/audio/stable_audio.py pick old_quarter 5 # trim, fade, normalise -> assets/audio/music/old_quarter.wav

Takes live in .audio/takes/<name>/ (Godot skips dot-folders). A looping sound's pick gets its seam crossfaded.
"""
from __future__ import annotations

import argparse
import datetime
import html
import json
import os
import re
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = os.path.join(ROOT, "data", "audio", "sounds.json")
AUDIO = os.path.join(ROOT, ".audio")
TAKES = os.path.join(AUDIO, "takes")
DEST = os.path.join(ROOT, "assets", "audio")


def load_spec() -> dict:
    with open(SPEC, encoding="utf-8") as f:
        return json.load(f)


def request(spec: dict, name: str) -> dict:
    s = spec["sounds"][name]
    req = dict(spec["defaults"])
    req.update(spec["sections"][s["section"]].get("defaults", {}))
    req.update(s)
    return req


def take_dir(name: str) -> str:
    return os.path.join(TAKES, name)


def take_name(name: str, n: int, seed: int) -> str:
    return f"{name}_{n:02d}_s{seed}.wav"


def take_number(path: str) -> int:
    return int(re.search(r"_(\d+)_s\d+\.wav$", path).group(1))


def takes(name: str) -> list[str]:
    d = take_dir(name)
    return sorted((os.path.join(d, f) for f in os.listdir(d) if f.endswith(".wav")), key=take_number) \
        if os.path.isdir(d) else []


def planned(req: dict) -> list[tuple[int, int, str, int]]:
    out, n = [], 0
    for v, prompt in enumerate(req["variants"], 1):
        for t in range(req["takes"]):
            n += 1
            out.append((n, 1000 * v + 37 * t + 11, prompt, v))
    return out


def cmd_gen(args, spec) -> None:
    import torch  # noqa: PLC0415
    import torchaudio  # noqa: PLC0415
    from stable_audio_3 import StableAudioModel  # noqa: PLC0415
    model = None
    names = args.names or list(spec["sounds"])
    # Short ones first: the page fills quickly, the long music last.
    names.sort(key=lambda n: request(spec, n)["duration"])
    for name in names:
        req = request(spec, name)
        d = take_dir(name)
        os.makedirs(d, exist_ok=True)
        todo = [p for p in planned(req) if not os.path.exists(os.path.join(d, take_name(name, p[0], p[1])))]
        print(f"{name}: {len(todo)} of {len(planned(req))} takes to make", flush=True)
        if todo and model is None:
            model = StableAudioModel.from_pretrained("medium")
        for n, seed, prompt, v in todo:
            # A little longer than wanted, so the generation's own fade-out can be cut away.
            dur = req["duration"] + (4.0 if req.get("loop") else 0.0)
            audio = model.generate(prompt=prompt, negative_prompt=req.get("negative_prompt") or None,
                                   duration=dur, steps=req.get("steps", 8), cfg_scale=1.0, seed=seed,
                                   batch_size=1, sample_size=model.model_config["sample_size"])
            out = os.path.join(d, take_name(name, n, seed))
            x = audio[0].cpu().float()
            x = x[:, :int(dur * model.model.sample_rate)]
            x = x / (x.abs().max() + 1e-9) * 0.9
            torchaudio.save(out, x, model.model.sample_rate)
            with open(out[:-4] + ".json", "w", encoding="utf-8") as f:
                json.dump({"prompt": prompt, "variant": v, "negative_prompt": req.get("negative_prompt", ""),
                           "duration": dur, "seed": seed, "backend": "local", "local_model": "medium",
                           "made": datetime.datetime.now().isoformat(timespec="seconds")}, f, indent=2)
            print(f"{name} take {n}: prompt {v}, seed {seed}", flush=True)
            torch.cuda.empty_cache()
    cmd_page(None, spec)


# ------------------------------------------------------------------ the page
STYLE = """
:root{--bg:#120d16;--panel:#1d1422;--line:#3a2840;--ink:#efe4c8;--dim:#a9969f;--rose:#c8203a;--brass:#c8a050}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 Georgia,serif}
main{max-width:1180px;margin:0 auto;padding:24px 16px 160px}h1{font-size:30px;margin:0 0 4px;color:var(--brass)}
.lede{color:var(--dim);margin:0 0 18px}nav{position:sticky;top:0;z-index:5;background:#120d16ee;padding:8px 0;
border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:6px 14px;font-size:13px}nav a{color:var(--dim)}
h2{margin:34px 0 4px;color:var(--rose);font-size:24px}.about{color:var(--dim);margin:0 0 10px}
h4{margin:22px 0 8px;color:var(--brass);font:600 13px/1 system-ui,sans-serif;text-transform:uppercase;letter-spacing:.08em}
.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin:0 0 14px}
.card.picked{border-color:var(--brass)}.card h3{margin:0 0 2px;font:600 17px system-ui,sans-serif}
.card h3 code{color:var(--ink)}.for{margin:0 0 10px;color:var(--dim)}.meta{color:var(--dim);font:12px system-ui}
.angle{margin:10px 0 0}.prompt{margin:0 0 6px;font-style:italic;color:#d8c8b8}
.takes{display:grid;grid-template-columns:repeat(auto-fill,minmax(310px,1fr));gap:8px}
.take{background:#150f19;border:1px solid var(--line);border-radius:8px;padding:6px 8px;display:flex;
flex-direction:column;gap:4px}.take label{font:13px system-ui;cursor:pointer}.take audio{width:100%;height:32px}
.take small{color:var(--dim);font:11px system-ui}.none{font:13px system-ui;color:var(--dim)}
input[type=radio]{accent-color:var(--rose)}#out{position:fixed;left:0;right:0;bottom:0;background:#0b080dee;
border-top:1px solid var(--line);padding:10px 16px}#out .row{max-width:1180px;margin:0 auto;display:flex;gap:10px;
align-items:flex-start}#out textarea{flex:1;height:90px;background:#150f19;color:var(--ink);border:1px solid var(--line);
border-radius:6px;font:12px ui-monospace,monospace;padding:6px}#out button{background:var(--rose);color:#fff;border:0;
border-radius:6px;padding:8px 14px;font:600 13px system-ui;cursor:pointer}#out .count{color:var(--dim);font:12px system-ui}
@media (max-width:640px){.takes{grid-template-columns:1fr}#out textarea{height:70px}}
"""

SCRIPT = """
const KEY='vesper-audition-picks';
function load(){try{return JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){return {}}}
function save(p){try{localStorage.setItem(KEY,JSON.stringify(p))}catch(e){}}
function refresh(){const picks={};document.querySelectorAll('input[type=radio]:checked').forEach(r=>{
 if(r.value!=='0')picks[r.name]=r.value});save(picks);
 document.querySelectorAll('.card').forEach(c=>{const r=c.querySelector('input:checked');
  c.classList.toggle('picked',!!r&&r.value!=='0')});
 const lines=Object.entries(picks).map(([n,t])=>'$SA3 tools/audio/stable_audio.py pick '+n+' '+t);
 document.getElementById('cmds').value=lines.join('\\n');
 document.getElementById('count').textContent=lines.length+' picked';}
document.addEventListener('DOMContentLoaded',()=>{const p=load();for(const [n,t] of Object.entries(p)){
 const r=document.querySelector(`input[name="${n}"][value="${t}"]`);if(r)r.checked=true}
 document.querySelectorAll('input[type=radio]').forEach(r=>r.addEventListener('change',refresh));
 // One take plays at a time.
 document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>{
  document.querySelectorAll('audio').forEach(b=>{if(b!==a)b.pause()})}));
 refresh();
 document.getElementById('copy').onclick=()=>{const t=document.getElementById('cmds');t.select();
  navigator.clipboard&&navigator.clipboard.writeText(t.value)};});
"""


def cmd_page(_args, spec) -> None:
    def rel(path):
        return os.path.relpath(path, AUDIO).replace(os.sep, "/")

    by_section: dict[str, dict[str, list[str]]] = {}
    total = made = 0
    for name, s in spec["sounds"].items():
        req = request(spec, name)
        ts = takes(name)
        total += 1
        made += len(ts)
        card = [f"<div class=card id='{name}'><h3><code>{html.escape(name)}</code> "
                f"<span class=meta>{req['duration']:g} s{' &middot; loops' if req.get('loop') else ''}</span></h3>",
                f"<p class=for>{html.escape(req.get('notes', ''))}</p>"]
        dest = os.path.join(DEST, s["section"], f"{name}.wav")
        if os.path.exists(dest):
            card.append(f"<div class=take><label>in the game now</label><audio controls preload=none "
                        f"src='{rel(dest)}'></audio></div>")
        card.append(f"<label class=none><input type=radio name='{name}' value='0' checked> none of these yet</label>")
        for v, prompt in enumerate(req["variants"], 1):
            group = []
            for p in ts:
                with open(p[:-4] + ".json", encoding="utf-8") as f:
                    meta = json.load(f)
                if meta.get("variant") != v:
                    continue
                n = take_number(p)
                group.append(f"<div class=take><label><input type=radio name='{name}' value='{n}'> take {n}</label>"
                             f"<audio controls preload=none src='{rel(p)}'></audio><small>seed {meta.get('seed')}</small></div>")
            card.append(f"<div class=angle><p class=prompt>prompt {v}: {html.escape(prompt)}</p><div class=takes>"
                        + ("".join(group) if group else "<small class=meta>(not made yet)</small>") + "</div></div>")
        card.append("</div>")
        by_section.setdefault(s["section"], {}).setdefault(s.get("group", ""), []).append("".join(card))
    body, nav = [], []
    for sec, sdef in spec["sections"].items():
        if sec not in by_section:
            continue
        nav.append(f"<a href='#sec-{sec}'>{html.escape(sdef['title'])}</a>")
        body.append(f"<h2 id='sec-{sec}'>{html.escape(sdef['title'])}</h2><p class=about>{html.escape(sdef.get('about', ''))}</p>")
        for group, cards in by_section[sec].items():
            if group:
                body.append(f"<h4>{html.escape(group)}</h4>")
            body.extend(cards)
    page = (f"<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
            f"<title>Vesper sound auditions</title><style>{STYLE}</style><script>{SCRIPT}</script><main>"
            f"<h1>The Velvet Claw: sound auditions</h1><p class=lede>{total} sounds, {made} takes. Three prompts each, three takes "
            f"of each; pick one take per sound (or leave it at none). Your picks are remembered in this browser, and the box "
            f"at the bottom collects them as commands for Claude to run. Made locally with Stable Audio 3 Medium "
            f"(data/audio/sounds.json).</p><nav>{' '.join(nav)}</nav>{''.join(body)}</main>"
            f"<div id=out><div class=row><textarea id=cmds readonly></textarea><div><button id=copy>Copy picks</button>"
            f"<p class=count id=count></p></div></div></div></html>")
    os.makedirs(AUDIO, exist_ok=True)
    with open(os.path.join(AUDIO, "audition.html"), "w", encoding="utf-8") as f:
        f.write(page)
    print(f"wrote .audio/audition.html: {total} sounds, {made} takes")


# ------------------------------------------------------------------ install a pick
def cmd_pick(args, spec) -> None:
    import torch  # noqa: PLC0415
    import torchaudio  # noqa: PLC0415
    req = request(spec, args.name)
    path = next((p for p in takes(args.name) if take_number(p) == args.take), None)
    if path is None:
        raise SystemExit(f"{args.name}: no take {args.take}")
    w, sr = torchaudio.load(path)
    x = w.numpy()
    if req.get("loop"):
        # Cut to the wanted length (the extra tail is the generation's fade), the seam crossfaded over 1.5 s
        # (0.25 s for a short loop), then -16 dB RMS (music) or -22 dB (beds), peak under -1 dB.
        n = int(req["duration"] * sr)
        fade = int(min(1.5, req["duration"] / 8) * sr)
        seg = x[:, :n + fade]
        loop = seg[:, :n].copy()
        t = np.linspace(0, np.pi / 2, fade)
        loop[:, :fade] = loop[:, :fade] * np.sin(t) + seg[:, n:n + fade] * np.cos(t)
        target = -16.0 if req["section"] == "music" else -22.0
        loop *= 10 ** (target / 20) / (np.sqrt((loop ** 2).mean()) + 1e-9)
        x = loop / max(1.0, np.abs(loop).max() / 10 ** (-1 / 20))
    else:
        # Trim the silence at both ends (-45 dB of the peak), a 5 ms fade in, 40 ms out, peak -1 dB; mono.
        x = x.mean(0, keepdims=True)
        peak = np.abs(x).max() + 1e-9
        loud = np.where(np.abs(x[0]) > peak * 10 ** (-45 / 20))[0]
        if len(loud):
            x = x[:, max(loud[0] - int(0.005 * sr), 0):loud[-1] + int(0.04 * sr)]
        fi, fo = int(0.005 * sr), int(0.04 * sr)
        x[:, :fi] *= np.linspace(0, 1, fi)
        x[:, -fo:] *= np.linspace(1, 0, fo)
        x = x / (np.abs(x).max() + 1e-9) * 10 ** (-1 / 20)
    d = os.path.join(DEST, req["section"])
    os.makedirs(d, exist_ok=True)
    dest = os.path.join(d, f"{args.name}.wav")
    torchaudio.save(dest, torch.from_numpy(x.astype(np.float32)), sr)
    print(f"{args.name}: take {args.take} -> {os.path.relpath(dest, ROOT)}")
    cmd_page(None, spec)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("names", nargs="*")
    sub.add_parser("page")
    k = sub.add_parser("pick")
    k.add_argument("name")
    k.add_argument("take", type=int)
    args = p.parse_args(argv)
    {"gen": cmd_gen, "page": cmd_page, "pick": cmd_pick}[args.cmd](args, load_spec())
    return 0


if __name__ == "__main__":
    sys.exit(main())
