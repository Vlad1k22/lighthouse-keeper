#!/usr/bin/env python3
"""Генерация нейроозвучки радиоэфира для «Смотрителя маяка».

1. Выгрузить реплики из игры:
   godot --headless --path . --script res://tools/voice/dump_lines.gd
   (создаёт tools/voice/lines.json)
2. Синтезировать и обработать под рацию:
   python3 tools/voice/generate_voice.py --piper /path/to/piper --model /path/to/ru-irinia-medium.onnx

Голос: Piper TTS (VITS), модель ru-irinia-medium (rhasspy/piper, релиз v0.0.2).
Нужен ffmpeg с libvorbis. Результат: assets/audio/voice/<id>.ogg
"""
import argparse
import json
import os
import re
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio", "voice")

STYLES = {
    # Диспетчер: полоса рации, компрессия, тихий эфирный шум.
    "dispatch": {
        "pre": "",
        "voice": "highpass=f=320,lowpass=f=3300,acompressor=threshold=0.08:ratio=4:attack=5:release=80,volume=1.5",
        "noise": "pink", "noise_amp": 0.018,
    },
    # Голос в эфире: ниже, с эхом, дрожанием и сильными помехами.
    "ghost": {
        "pre": "asetrate=22050*0.84,aresample=22050,asetpts=N/SR/TB,atempo=1.1,",
        "voice": "highpass=f=250,lowpass=f=2900,aecho=0.8:0.6:70|140:0.35|0.2,tremolo=f=5.5:d=0.3,volume=1.7",
        "noise": "brown", "noise_amp": 0.05,
    },
    # Портрет капитана: низкий «пиратский» голос в деревянной рубке, без рации.
    "captain": {
        "pre": "asetrate=22050*0.76,aresample=22050,asetpts=N/SR/TB,atempo=1.08,",
        "voice": "highpass=f=90,lowpass=f=5200,aecho=0.7:0.5:35|60:0.25|0.15,volume=1.9",
        "noise": "brown", "noise_amp": 0.004,
        "stretch": 1.0 / (0.76 * 1.08),
    },
    # Старая плёнка: узкая полоса, плавание скорости, шипение.
    "record": {
        "pre": "",
        "voice": "highpass=f=420,lowpass=f=2700,vibrato=f=0.8:d=0.12,acrusher=bits=10:mix=0.4,volume=1.6",
        "noise": "white", "noise_amp": 0.02,
    },
}


def speakable(text: str) -> str:
    text = text.replace("«", "").replace("»", "").replace("“", "").replace("”", "")
    text = text.replace("…", ", ").replace(" — ", ", ").replace("—", ", ")
    text = re.sub(r"\s+", " ", text)
    return text.strip(" ,")


def duration(path: str) -> float:
    out = subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path])
    return float(out.strip())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--piper", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--lines", default=os.path.join(ROOT, "tools", "voice", "lines.json"))
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    lines = json.load(open(args.lines, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for line_id, line in lines.items():
            if args.only and line_id not in args.only:
                continue
            raw = os.path.join(tmp, line_id + ".wav")
            spoken = speakable(line.get("say") or line["text"])
            subprocess.run([args.piper, "--model", args.model, "--output_file", raw, "--length_scale", "1.04", "--sentence_silence", "0.25"],
                           input=spoken.encode("utf-8"), check=True, stderr=subprocess.DEVNULL)
            style = STYLES[line.get("style", "dispatch")]
            # Призрачный голос замедлен (asetrate 0.84) и чуть ускорен atempo 1.1: итог длиннее в 1/(0.84*1.1) раза.
            stretch = style.get("stretch", 1.0 / (0.84 * 1.1) if line.get("style") == "ghost" else 1.0)
            length = duration(raw) * stretch + 0.9
            graph = (
                f"[0:a]{style['pre']}adelay=320|320,apad=pad_dur=0.45,{style['voice']}[v];"
                f"[1:a]highpass=f=400,lowpass=f=4200[n];"
                f"[v][n]amix=inputs=2:duration=first:normalize=0,"
                f"afade=t=in:d=0.04,afade=t=out:st={max(0.1, length - 0.15):.2f}:d=0.15"
            )
            target = os.path.join(OUT, line_id + ".ogg")
            processed = os.path.join(tmp, line_id + "_radio.wav")
            subprocess.run([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", raw,
                "-f", "lavfi", "-i", f"anoisesrc=d={length + 1:.2f}:c={style['noise']}:a={style['noise_amp']}:r=22050",
                "-filter_complex", graph, "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", processed,
            ], check=True)
            # Второй проход: чистая перекодировка без фильтров, чтобы у OGG были корректные метки времени.
            subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", processed,
                            "-c:a", "libvorbis", "-q:a", "4", target], check=True)
            print(f"{line_id}: {duration(target):.1f} c — {spoken[:60]}")


if __name__ == "__main__":
    main()
