export const audioPlayer = document.getElementById('audio-player');
export const lyricsBody = document.getElementById('lyrics-body');
export const songList = document.getElementById('song-list');
export const playbackQueueSongs = document.getElementById('playback-queue-songs');

export const shared = {
    lyricsBodyActive: false,
    loadingPlaylist: false,
    playbackQueueDisplay: false
}

export function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

class LyricsPlayer {
    constructor() {
        this.lines = [];
        this.lineElements = [];
        this.container = document.getElementById('lyrics-container');
        this.currentLineIndex = -1;
    }

    // Parse LRC file content
    parseLyrics(lrcText) {
        this.clear();
        const lines = lrcText.split('\n');
        this.lines = lines
            .map(line => {
                const timeMatch =
                    line.match(/^\[(\d{2}):(\d{2})[:.](\d{2})\](.*)/);
                if (timeMatch) {
                    const minutes = parseInt(timeMatch[1]);
                    const seconds = parseInt(timeMatch[2]);
                    const hundredths = parseInt(timeMatch[3]);
                    return {
                        time: minutes * 60 + seconds + hundredths / 100,
                        text: timeMatch[4].trim()
                    };
                }
                return null;
            })
            .filter(line => line !== null);

        for (let lineIndex = 0; lineIndex < this.lines.length; lineIndex++) {
            const lineElement = document.createElement('div');
            lineElement.className = 'lyrics-line';
            lineElement.textContent = this.lines[lineIndex].text;
            lineElement.addEventListener('click', () => {
                audioPlayer.currentTime = this.lines[lineIndex].time;
            });
            this.lineElements.push(lineElement);
            this.container.appendChild(lineElement);
        }
    }

    // Update display based on current audio time
    update() {
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
        let currentLineElement = this.container.querySelector('.current-line');
        if (currentLineElement) {
            currentLineElement.classList.remove('current-line');
        }
        currentLineElement = this.lineElements[this.currentLineIndex];
        currentLineElement.classList.add('current-line');

        if (shared.lyricsBodyActive)
            this.container.scrollTo({
                top: currentLineElement.offsetTop - this.container.clientHeight / 2,
                behavior: 'smooth'
            });
    }

    clear() {
        this.lines = [];
        this.lineElements = [];
        this.currentLineIndex = -1;
        this.container.innerHTML = "";
    }
}

export const lyricsPlayer = new LyricsPlayer();

async function loadLyricsForSong(lrcPath) {
    try {
        const response = await fetch(lrcPath);
        const lrcText = await response.text();

        lyricsPlayer.parseLyrics(lrcText);
    } catch (error) {
        console.error('Error loading lyrics:', error);
        document.getElementById('lyrics-display').textContent =
            'Lyrics not available';
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
        loadLyricsForSong(src.replace(/\.[^/.]+$/, '.lrc'));
        audioPlayer.currentTime = 0;

        window.electronAPI.getColor(src).then((color) => {
            const coverDataUrl = this.currentSong.children[0].children[0].src;
            if (color == null)
                setCover({ coverDataUrl: coverDataUrl, color: defaultCover.color });
            else
                setCover({ coverDataUrl: coverDataUrl, color: color });
        })

        document.getElementById('left-bottom-title').textContent = this.currentSong.children[0].children[1].textContent;
        document.getElementById('left-bottom-artist').textContent = this.currentSong.children[0].children[2].textContent;

        document.querySelectorAll('.song-line').forEach(element => {
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
    document.getElementById('cover-art-bigger').src = result.coverDataUrl;
    document.getElementById('lyrics-body').style.backgroundColor = result.color;
}

let defaultCover;
window.electronAPI.setDefaultCover((result) => {
    defaultCover = result;
    setCover(result);
})