#!/usr/bin/env python3
"""Generuje proceduralne efekty dźwiękowe i tła do audio/ (WAV 16-bit mono 22050 Hz). Wymaga numpy.
Uruchom: python3 tools/gen_audio.py. Wynik jest w repozytorium, więc gra nie wymaga uruchamiania skryptu."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(12345)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lp(x, fc):
    a = 1 - np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a * (x[i] - s)
        y[i] = s
    return y


def hp(x, fc):
    return x - lp(x, fc)


def bp(x, f0, q=4.0):
    """Rezonator (biquad pasmowy)."""
    w0 = 2 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, v
        y[i] = v
    return y


def env(n, tau, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def sine_sweep(dur, f0, f1, tau=None):
    t = t_(dur)
    f = f0 + (f1 - f0) * (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph)
    return s * (env(len(t), tau) if tau else 1)


def saw(f, dur):
    t = t_(dur)
    ph = np.cumsum(np.broadcast_to(f, t.shape)) / SR
    return 2 * (ph % 1.0) - 1


def pad(x, dur):
    n = int(SR * dur)
    out = np.zeros(n)
    out[:min(n, len(x))] = x[:n]
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- strzały
def gunshot(dur, noise_fc, noise_tau, thump_f0, thump_f1, thump_tau, tail_tau, tail_fc=700, tail_gain=0.25):
    n = int(SR * dur)
    crack = hp(noise(0.012), 2000)
    body = lp(noise(dur), noise_fc) * env(n, noise_tau, 0.0005)
    thump = sine_sweep(dur, thump_f0, thump_f1, thump_tau) * 0.9
    tail = lp(noise(dur), tail_fc) * env(n, tail_tau, 0.004) * tail_gain
    return norm(mix(pad(crack, dur) * 0.8, body, thump, tail))


def make_weapons():
    save("shot_rifle", gunshot(0.5, 5200, 0.06, 95, 45, 0.09, 0.22))
    save("shot_smg", gunshot(0.25, 6000, 0.03, 130, 65, 0.05, 0.1, 900, 0.15))
    save("shot_pistol", gunshot(0.32, 4600, 0.045, 150, 75, 0.06, 0.14))
    save("shot_dmr", gunshot(0.9, 3600, 0.13, 70, 32, 0.22, 0.5, 520, 0.4))
    # strzały wrogów – każda frakcja ma własną "sygnaturę"
    save("shot_enemy_a", gunshot(0.3, 2800, 0.05, 110, 60, 0.07, 0.13, 600, 0.2))      # Szabrownicy: tępy
    save("shot_enemy_b", gunshot(0.28, 7000, 0.035, 160, 90, 0.05, 0.12, 1100, 0.2))   # Najemnicy: ostry
    save("shot_enemy_c", gunshot(0.5, 4200, 0.09, 80, 40, 0.14, 0.3, 480, 0.3))        # Wojskowi: głęboki
    click = hp(noise(0.006), 1500)
    save("empty_click", norm(mix(pad(click, 0.18), np.roll(pad(click * 0.6, 0.18), int(SR * 0.05)))))
    scrape = bp(noise(0.2), 2800, 2) * env(int(SR * 0.2), 0.08)
    save("reload_start", norm(mix(pad(click * 3, 0.25), np.roll(pad(scrape * 0.5, 0.25), int(SR * 0.03)))))
    thunk = sine_sweep(0.12, 200, 90, 0.04)
    clack = hp(noise(0.015), 1200)
    save("reload_end", norm(mix(pad(thunk, 0.5), np.roll(pad(clack * 3, 0.5), int(SR * 0.22)), np.roll(pad(clack * 2, 0.5), int(SR * 0.31)))))
    save("swap_weapon", norm(mix(pad(bp(noise(0.12), 1800, 2) * env(int(SR * 0.12), 0.05), 0.2), np.roll(pad(click * 2, 0.2), int(SR * 0.1)))))


# ---------------------------------------------------------------- trafienia, ciało
def make_impacts():
    n = int(SR * 0.2)
    flesh = mix(lp(noise(0.2), 900) * env(n, 0.04), sine_sweep(0.2, 120, 55, 0.05) * 0.8)
    save("hit_flesh", norm(flesh))
    ping = (np.sin(2 * np.pi * 2200 * t_(0.35)) + 0.6 * np.sin(2 * np.pi * 3100 * t_(0.35)) + 0.4 * np.sin(2 * np.pi * 4700 * t_(0.35))) * env(int(SR * 0.35), 0.07)
    save("hit_armor", norm(mix(ping * 0.7, pad(hp(noise(0.01), 3000), 0.35))))
    save("hit_confirm", norm(np.sin(2 * np.pi * 1700 * t_(0.05)) * env(int(SR * 0.05), 0.012)) * 0.9)
    save("hit_wall", norm(mix(hp(noise(0.08), 1200) * env(int(SR * 0.08), 0.015), pad(sine_sweep(0.08, 300, 180, 0.02) * 0.5, 0.08))))
    hurt = mix(sine_sweep(0.3, 110, 70, 0.1), lp(noise(0.3), 500) * env(int(SR * 0.3), 0.08) * 0.8)
    save("hurt", norm(hurt))
    save("die_player", norm(mix(sine_sweep(1.4, 120, 28, 0.6), lp(noise(1.4), 300) * env(int(SR * 1.4), 0.4) * 0.6)))
    save("die_enemy", norm(mix(lp(noise(0.4), 700) * env(int(SR * 0.4), 0.12), sine_sweep(0.4, 160, 50, 0.12) * 0.8)))
    # kroki
    for i, fc in enumerate([650, 900, 1100]):
        stp = lp(noise(0.09), fc) * env(int(SR * 0.09), 0.018)
        th = sine_sweep(0.09, 85 + i * 8, 55, 0.025) * 0.6
        save("step_%d" % i, norm(mix(stp, th), 0.6))
    # serce
    beat = sine_sweep(0.16, 62, 38, 0.045)
    hb = mix(pad(beat, 0.9), np.roll(pad(beat * 0.7, 0.9), int(SR * 0.22)))
    save("heartbeat", norm(hb))


# ---------------------------------------------------------------- interfejs, leczenie, łup
def make_ui():
    def blip(f, d, tau=None):
        return np.sin(2 * np.pi * f * t_(d)) * env(int(SR * d), tau or d / 3)
    save("pickup", norm(mix(pad(blip(880, 0.08), 0.18), np.roll(pad(blip(1320, 0.09), 0.18), int(SR * 0.07)))) * 0.8)
    save("ui_click", norm(blip(1250, 0.035, 0.01)) * 0.7)
    # nabój wsuwany do magazynka: krótki metaliczny stuk
    tick = bp(noise(0.03), 3200, 5) * env(int(SR * 0.03), 0.008) + 0.5 * blip(2400, 0.03, 0.006)
    save("ammo_tick", norm(tick) * 0.7)
    save("ui_deny", norm(np.sign(np.sin(2 * np.pi * 150 * t_(0.14))) * env(int(SR * 0.14), 0.06)) * 0.5)
    coin = (blip(1400, 0.3, 0.09) + 0.6 * blip(2100, 0.3, 0.06) + 0.3 * blip(2800, 0.3, 0.05))
    save("ui_buy", norm(mix(pad(coin, 0.4), np.roll(pad(coin * 0.7, 0.4), int(SR * 0.06)))) * 0.8)
    save("ui_sell", norm(mix(pad(blip(1900, 0.2, 0.06), 0.35), np.roll(pad(blip(1400, 0.25, 0.08), 0.35), int(SR * 0.07)))) * 0.8)
    rustle = bp(noise(0.55), 3200, 1.5) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t_(0.55))) * env(int(SR * 0.55), 0.3)
    save("bandage", norm(rustle) * 0.8)
    inj = mix(pad(hp(noise(0.012), 1500) * 3, 0.5), np.roll(hp(noise(0.5), 3500) * env(int(SR * 0.5), 0.12), int(SR * 0.05)) * 0.5)
    save("injector", norm(inj) * 0.8)
    creak = bp(saw(180 + 60 * np.sin(2 * np.pi * 3 * t_(0.4)), 0.4), 420, 6) * env(int(SR * 0.4), 0.25)
    save("loot_open", norm(creak) * 0.7)
    save("loot_reveal", norm(blip(1000, 0.05, 0.015)) * 0.6)
    save("key_found", norm(mix(*[np.roll(pad(blip(f, 0.25, 0.1), 0.6), int(SR * 0.09 * i)) for i, f in enumerate([880, 1175, 1568])])) * 0.8)
    save("quest_done", norm(mix(*[np.roll(pad(blip(f, 0.3, 0.12), 0.8), int(SR * 0.1 * i)) for i, f in enumerate([523, 659, 784, 1047])])) * 0.8)
    save("extract_tick", norm(blip(900, 0.07, 0.03)) * 0.7)
    save("extract_done", norm(mix(*[np.roll(pad(blip(f, 0.22, 0.09), 0.7), int(SR * 0.1 * i)) for i, f in enumerate([600, 800, 1000, 1200])])) * 0.8)
    save("doc_read", norm(bp(noise(0.25), 2600, 1.2) * env(int(SR * 0.25), 0.1)) * 0.5)


# ---------------------------------------------------------------- fauna, frakcje
def vowel(f0, dur, f1_a, f2_a, f1_b, f2_b, rough=0.0):
    """Syntetyczny okrzyk: źródło piłokształtne przez dwa formanty (przesuwane)."""
    n = int(SR * dur)
    f0t = f0 * (1 + 0.18 * np.sin(np.pi * np.linspace(0, 1, n)))  # intonacja
    src = saw(f0t, dur) + rough * noise(dur)
    h = n // 2
    a = bp(src[:h], f1_a, 5) + bp(src[:h], f2_a, 6) * 0.6
    b = bp(src[h:], f1_b, 5) + bp(src[h:], f2_b, 6) * 0.6
    y = np.concatenate([a, b])
    e = np.sin(np.pi * np.linspace(0, 1, n)) ** 0.6
    return norm(y * e)


def make_creatures():
    save("bite", norm(mix(lp(noise(0.16), 1600) * env(int(SR * 0.16), 0.04), sine_sweep(0.16, 220, 90, 0.05) * 0.7)))
    scr = vowel(300, 0.6, 500, 1500, 900, 2200, 0.35)
    save("fauna_screech", scr * 0.9)
    save("fauna_die", norm(vowel(240, 0.7, 800, 1800, 400, 900, 0.5) * np.linspace(1, 0.1, int(SR * 0.7))))
    save("bark_a", vowel(125, 0.38, 600, 1100, 450, 1700, 0.15) * 0.9)   # Szabrownicy: chropawy
    save("bark_b", vowel(165, 0.3, 700, 1300, 520, 1900, 0.05) * 0.9)    # Najemnicy: ostry
    save("bark_c", vowel(105, 0.42, 550, 1000, 420, 1400, 0.08) * 0.9)   # Wojskowi: niski
    def beep(f, d):
        return np.sign(np.sin(2 * np.pi * f * t_(d))) * 0.5 * env(int(SR * d), d / 2.5)
    save("radio_a", norm(mix(pad(hp(noise(0.25), 800) * env(int(SR * 0.25), 0.1), 0.35), np.roll(pad(beep(1200, 0.08), 0.35), int(SR * 0.2)))) * 0.7)
    save("radio_b", norm(mix(pad(beep(1700, 0.05), 0.3), np.roll(pad(beep(1700, 0.05), 0.3), int(SR * 0.1)), pad(hp(noise(0.3), 2500) * 0.05, 0.3))) * 0.7)
    save("radio_c", norm(mix(pad(beep(700, 0.12), 0.35), pad(lp(noise(0.35), 2200) * env(int(SR * 0.35), 0.15) * 0.4, 0.35))) * 0.7)
    stab = mix(saw(90, 0.5) * env(int(SR * 0.5), 0.14), saw(95, 0.5) * env(int(SR * 0.5), 0.14), lp(noise(0.5), 400) * 0.5 * env(int(SR * 0.5), 0.2))
    save("alert", norm(lp(stab, 900)) * 0.9)


# ---------------------------------------------------------------- tła (pętle)
def loopable(x, fade=0.6):
    f = int(SR * fade)
    out = x[:-f].copy()
    out[:f] = out[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return out


def make_ambient():
    dur = 11.0
    t = t_(dur)
    n = len(t)
    # przedmieścia: wiatr i odległe stuki
    wind = lp(noise(dur), 380) * (0.55 + 0.45 * np.sin(2 * np.pi * (1 / 5.5) * t))
    wind += lp(noise(dur), 900) * 0.12 * (0.5 + 0.5 * np.sin(2 * np.pi * (1 / 3.0) * t + 1))
    drone = np.sin(2 * np.pi * 55 * t) * 0.05
    tick = np.zeros(n)
    for pos in (2.4, 6.1, 8.7):
        i = int(SR * pos)
        tick[i:i + int(SR * 0.05)] += hp(noise(0.05), 1500) * env(int(SR * 0.05), 0.01) * 0.25
    save("amb_suburb", norm(loopable(wind + drone + tick), 0.5))
    # kompleks: wentylacja, buczenie, piknięcia
    hum = (np.sin(2 * np.pi * 50 * t) * 0.3 + np.sin(2 * np.pi * 100 * t) * 0.18 + np.sin(2 * np.pi * 150 * t + 1) * 0.08)
    fan = lp(noise(dur), 1100) * 0.18 * (0.8 + 0.2 * np.sin(2 * np.pi * 4 * t))
    bleeps = np.zeros(n)
    for pos in (1.7, 5.3, 9.4):
        i = int(SR * pos)
        b = np.sin(2 * np.pi * 2400 * t_(0.06)) * env(int(SR * 0.06), 0.02) * 0.12
        bleeps[i:i + len(b)] += b
    save("amb_lab", norm(loopable(hum + fan + bleeps), 0.5))
    # baza: schron, szum radia
    rumble = np.sin(2 * np.pi * 42 * t) * 0.25 + lp(noise(dur), 300) * 0.25
    pops = np.zeros(n)
    for pos in (1.1, 3.9, 4.0, 7.2, 9.9):
        i = int(SR * pos)
        pops[i:i + int(SR * 0.02)] += hp(noise(0.02), 1000) * 0.3
    hiss = hp(noise(dur), 3500) * 0.03
    save("amb_base", norm(loopable(rumble + pops + hiss), 0.45))
    # szepty anomalii
    d2 = 7.0
    wh = noise(d2)
    t2 = t_(d2)
    out = np.zeros(len(t2))
    for k, (f, q) in enumerate(((600, 8), (1400, 10), (2300, 12))):
        seg = bp(wh, f, q) * (0.5 + 0.5 * np.sin(2 * np.pi * (0.3 + 0.17 * k) * t2 + k))
        out += seg
    save("anomaly_whisper", norm(loopable(out, 0.5), 0.5))


if __name__ == "__main__":
    make_weapons(); make_impacts(); make_ui(); make_creatures(); make_ambient()
    print("audio ok:", len(os.listdir(OUT)), "plików")
