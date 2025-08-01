export const audioPlayer = document.getElementById('audio-player');
export const lyricsBody = document.getElementById('lyrics-body');

export const shared = {
    lyricBodyActive: false,
    loadingPlaylist: false,
    playbackQueueDisplay: false,
    playlist: []
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
        this.container = document.getElementById('lyrics-display');
        this.currentLineIndex = -1;
    }

    // Parse LRC file content
    parseLyrics(lrcText) {
        this.clear();
        const lines = lrcText.split('\n');
        this.lines = lines
            .map(line => {
                const timeMatch =
                    line.match(/^\[(\d{2}):(\d{2}):(\d{2})\](.*)/);
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
        if (shared.lyricBodyActive)
            currentLineElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
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
        this.metadatas = [];
        this.currentMetadata = [];
        this.currentIndex = 0;
        this.playMode = 0;
        this.actualCurrentIndex = 0;
        this.randomIndex = [];
    }

    load() {
        this.actualCurrentIndex = this.currentIndex;
        if (this.playMode == 2)
            this.actualCurrentIndex = this.randomIndex[this.currentIndex];

        this.currentMetadata = this.metadatas[this.actualCurrentIndex];
        let src = this.currentMetadata.filePath;
        audioPlayer.src = src;
        loadLyricsForSong(src.replace(/\.[^/.]+$/, '.lrc'));
        audioPlayer.currentTime = 0;
    }

    last() {
        audioPlayer.pause();
        if (this.currentIndex == 0)
            this.currentIndex = this.metadatas.length - 1;
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
        document.querySelectorAll('.song-line').forEach(element => {
            if (shared.playlist[element.children[0].textContent - 1].filePath ==
                this.currentMetadata.filePath) {
                element.style.background = 'rgba(220, 220, 220, 0.5)';
            } else {
                element.style.background = '';
            }
        });
    }

    next() {
        audioPlayer.pause();
        if (this.currentIndex == this.metadatas.length - 1)
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
                this.currentIndex = this.actualCurrentIndex;
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/loop.png\')';
                    });
                break;
            }
            case 1: {
                this.currentIndex = this.actualCurrentIndex;
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/repeat.png\')';
                    });
                break;
            }
            case 2: {
                this.generateRandom();
                document.querySelectorAll('.play-mode-btn')
                    .forEach(element => {
                        element.style.backgroundImage = 'url(\'pictures/random.png\')';
                    });
                break;
            }
        }
    }

    generateRandom() {
        this.randomIndex = [];
        for (let i = 0; i < this.metadatas.length; i++) {
            this.randomIndex.push(getRandomInt(0, this.metadatas.length));
        }
        if (this.metadatas.length)
            // keep current index unchanged
            this.randomIndex[this.currentIndex] = this.currentIndex;
    }

    clear() {
        this.play = false;
        this.empty = true;
        this.metadatas = [];
        this.currentMetadata = [];
        this.currentIndex = 0;
    }
}

export const playbackQueue = new PlaybackQueue();