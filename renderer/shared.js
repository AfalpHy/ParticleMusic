export const audioPlayer = document.getElementById('audio-player');
export const lyricsPlane = document.getElementById('lyrics-plane');
export const songList = document.getElementById('song-list');
export const playbackQueueSongs = document.getElementById('playback-queue-songs');

const lyricsContainer = document.getElementById('lyrics-container');

export const shared = {
    lyricsPlaneActive: false,
    loadingPlaylist: false,
    playbackQueueDisplay: false
}

export function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

let contrast;
function getContrastRatio(color1, color2) {
    const [r1, g1, b1] = hexToRgb(color1);
    const [r2, g2, b2] = hexToRgb(color2);
    const l1 = calculateLuminance(r1, g1, b1);
    const l2 = calculateLuminance(r2, g2, b2);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

function hexToRgb(hex) {
    hex = hex.replace(/^#/, '');
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    return [r, g, b];
}

function calculateLuminance(r, g, b) {
    const [r1, g1, b1] = [r, g, b].map(v => {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r1 + 0.7152 * g1 + 0.0722 * b1;
}

function calculateRequiredContrast(textColor, bgColor) {
    const targetRatio = 4.5;
    const currentRatio = getContrastRatio(textColor, bgColor);

    if (currentRatio >= targetRatio) {
        return 1;
    }

    return targetRatio / currentRatio;
}

class LyricsPlayer {
    constructor() {
        this.lines = [];
        this.lineElements = [];
        this.currentLineIndex = -1;
        this.sync;
    }

    // Parse LRC file content
    parseLyrics(lyrics, pureText) {
        this.clear();
        this.sync = false;
        if (pureText) {
            const lines = lyrics.split('\n');
            this.lines = lines
                .map(line => {
                    const timeMatch =
                        line.match(/^\[(\d{2}):(\d{2})[:.](\d{2,3})\](.*)/);
                    if (timeMatch) {
                        this.sync = true;
                        const minutes = parseInt(timeMatch[1]);
                        const seconds = parseInt(timeMatch[2]);
                        const hundredths = parseInt(timeMatch[3]);
                        return {
                            time: minutes * 60 + seconds + hundredths / (hundredths < 100 ? 100 : 1000),
                            text: timeMatch[4].trim()
                        };
                    } else {
                        return {
                            time: -1,
                            text: line
                        };
                    }
                })
                .filter(line => this.sync ? line.time >= 0 : true);
        } else {
            lyrics.forEach(line => {
                this.lines.push({ time: line.time / 1000, text: line.text });
            })
        }

        for (let lineIndex = 0; lineIndex < this.lines.length; lineIndex++) {
            const lineElement = document.createElement('div');
            lineElement.className = 'lyrics-line';
            lineElement.textContent = this.lines[lineIndex].text;
            lineElement.style.filter = 'contrast(' + contrast + ')';
            lineElement.addEventListener('click', () => {
                if (this.sync) {
                    audioPlayer.currentTime = this.lines[lineIndex].time;
                }
            });
            this.lineElements.push(lineElement);
            lyricsContainer.appendChild(lineElement);
        }
    }

    // Update display based on current audio time
    update() {
        if (!this.sync) {
            return;
        }
        const currentTime = audioPlayer.currentTime;
        let activeLineIndex = -1;

        // Find the current active line
        for (let i = 0; i < this.lines.length; i++) {
            if (this.lines[i].time <= currentTime) {
                activeLineIndex = i;
            } else {
                break;
            }
        }
        // Only update if line changed
        if (activeLineIndex >= 0 && activeLineIndex !== this.currentLineIndex) {
            this.currentLineIndex = activeLineIndex;
            this.render();
        }
    }

    render() {
        // Auto-scroll to current line
        let currentLineElement = lyricsContainer.querySelector('.current-line');
        if (currentLineElement) {
            currentLineElement.classList.remove('current-line');
        }
        currentLineElement = this.lineElements[this.currentLineIndex];
        currentLineElement.classList.add('current-line');

        if (shared.lyricsPlaneActive)
            lyricsContainer.scrollTo({
                top: currentLineElement.offsetTop - lyricsContainer.clientHeight / 2,
                behavior: 'smooth'
            });
    }

    clear() {
        this.lines = [];
        this.lineElements = [];
        this.currentLineIndex = -1;
        lyricsContainer.innerHTML = "";
    }
}

export const lyricsPlayer = new LyricsPlayer();

async function loadLyricsForSong(lrcPath) {
    try {
        const response = await fetch(lrcPath);
        const lrcText = await response.text();

        lyricsPlayer.parseLyrics(lrcText, true);
    } catch (error) {
        lyricsPlayer.parseLyrics('Lyrics not available', true);
    }
}

function getRandomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

class PlaybackQueue {
    constructor() {
        this.play = false;
        this.empty = true;
        this.currentSong;
        this.currentIndex = 0;
        this.playMode = 0;
        this.songLines = [];
    }

    load() {
        this.currentSong = playbackQueueSongs.children[this.currentIndex];
        let src = this.currentSong.filePath;
        audioPlayer.src = src;
        audioPlayer.currentTime = 0;

        window.electronAPI.getColor(src).then((color) => {
            const coverDataUrl = this.currentSong.children[0].children[0].src;
            if (color == null) {
                contrast = calculateRequiredContrast('#A0A0A0', defaultCover.color)
                setCover({ coverDataUrl: coverDataUrl, color: defaultCover.color });
            } else {
                contrast = calculateRequiredContrast('#A0A0A0', color)
                setCover({ coverDataUrl: coverDataUrl, color: color });
            }

            window.electronAPI.getLyrics(src).then((result) => {
                if (result) {
                    lyricsPlayer.parseLyrics(result.lyrics, result.pureText);
                } else {
                    loadLyricsForSong(src.replace(/\.[^/.]+$/, '.lrc'));
                }
            });
        })

        document.getElementById('left-bottom-title').textContent = this.currentSong.children[0].children[1].textContent;
        document.getElementById('left-bottom-artist').textContent = this.currentSong.children[0].children[2].textContent;

        document.getElementById('lyrics-plane-title').textContent = this.currentSong.children[0].children[1].textContent;
        document.getElementById('lyrics-plane-artist').textContent = this.currentSong.children[0].children[2].textContent;

        document.querySelectorAll('.song-line').forEach(element => {
            if (element.filePath == src) {
                element.style.background = 'rgba(220, 220, 220, 0.5)';
            } else {
                element.style.background = '';
            }
        });
        document.querySelectorAll('.playback-queue-song-line').forEach(element => {
            if (element.filePath == src) {
                element.style.background = 'rgba(220, 220, 220, 0.5)';
            } else {
                element.style.background = '';
            }
        });
    }

    last() {
        audioPlayer.pause();
        if (this.currentIndex == 0)
            this.currentIndex = playbackQueueSongs.children.length - 1;
        else
            this.currentIndex -= 1;
        this.load();
        this.playOrPause();
    }

    playOrPause() {
        if (this.play) {
            document.querySelectorAll('.play-pause-btn').forEach(element => {
                element.style.backgroundImage = 'url(\'pictures/pause.png\')';
            });
            audioPlayer.play();
        } else {
            document.querySelectorAll('.play-pause-btn').forEach(element => {
                element.style.backgroundImage = 'url(\'pictures/play.png\')';
            });
            audioPlayer.pause();
        }

    }

    next() {
        audioPlayer.pause();
        if (this.currentIndex == playbackQueueSongs.children.length - 1)
            this.currentIndex = 0;
        else
            this.currentIndex += 1;
        this.load();
        this.playOrPause();
    }

    switchPlayMode() {
        this.playMode += 1;
        this.playMode %= 3;
        switch (this.playMode) {
            case 0: {
                if (!this.empty) {
                    this.songLines.forEach(line => {
                        playbackQueueSongs.appendChild(line);
                    })
                    for (let i = 1; i < songList.children.length; i++) {
                        if (songList.children[i].filePath == this.currentSong.filePath) {
                            this.currentIndex = i - 1;
                            break
                        }
                    }
                }
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/loop.png\')';
                    });
                break;
            }
            case 1: {
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/repeat.png\')';
                    });
                break;
            }
            case 2: {
                this.shuffle();
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/shuffle.png\')';
                    });
                break;
            }
        }
    }

    shuffle() {
        if (!this.empty) {
            playbackQueueSongs.appendChild(this.currentSong);
            this.currentIndex = 0;
            for (let i = 1; i < playbackQueueSongs.children.length; i++) {
                const song = playbackQueueSongs.children[(getRandomInt(0, playbackQueueSongs.children.length - i - 1))];
                playbackQueueSongs.appendChild(song);
            }
        }
    }

    clear() {
        this.play = false;
        this.empty = true;
        this.currentIndex = 0;

        setCover(defaultCover);
        document.getElementById('left-bottom-title').textContent = 'Title';
        document.getElementById('left-bottom-artist').textContent = "Artist";
    }
}

export const playbackQueue = new PlaybackQueue();

function setCover(result) {
    document.getElementById('cover-art').src = result.coverDataUrl;
    document.getElementById('lyrics-plane-cover-art').src = result.coverDataUrl;
    document.getElementById('lyrics-plane').style.backgroundColor = result.color;
}

let defaultCover;
window.electronAPI.setDefaultCover((result) => {
    defaultCover = result;
    setCover(result);
})