
const selectFileBtn = document.getElementById('selectFile');
const playBtn = document.getElementById('playBtn');
const pauseBtn = document.getElementById('pauseBtn');
const stopBtn = document.getElementById('stopBtn');
const volumeSlider = document.getElementById('volume');
const fileInfoDiv = document.getElementById('fileInfo');
const audioPlayer = document.getElementById('audioPlayer');
const timeDisplay = document.getElementById('timeDisplay');
const progressBar = document.getElementById('progress');

class LyricsPlayer {
  constructor(audioElement) {
    this.audio = audioElement;
    this.lines = [];
    this.container = document.getElementById('lyrics-display');
    this.currentLineIndex = -1;
  }

  // Parse LRC file content
  parseLyrics(lrcText) {
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
  }

  // Update display based on current audio time
  update() {
    const currentTime = this.audio.currentTime;
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
    if (activeLineIndex !== this.currentLineIndex) {
      this.currentLineIndex = activeLineIndex;
      this.render();
    }

    requestAnimationFrame(() => this.update());
  }

  render() {
    this.container.innerHTML = '';

    for (let i = -3; i <= 3; i++) {
      const lineIndex = this.currentLineIndex + i;
      if (lineIndex >= 0 && lineIndex < this.lines.length) {
        const lineElement = document.createElement('div');
        lineElement.className = 'lyrics-line';
        lineElement.textContent = this.lines[lineIndex].text;

        if (i === 0) {
          lineElement.classList.add('current-line');
        } else {
          // Fade lines based on distance from current line
          const opacity = 1 - Math.min(0.7, Math.abs(i) * 0.2);
          lineElement.style.opacity = opacity;
        }

        this.container.appendChild(lineElement);
      }
    }

    // Auto-scroll to current line
    const currentLineElement = this.container.querySelector('.current-line');
    if (currentLineElement) {
      currentLineElement.scrollIntoView({behavior: 'smooth', block: 'center'});
    }
  }
}

const lyricsPlayer = new LyricsPlayer(audioPlayer);

async function loadLyricsForSong(lyricPatg) {
  try {
    const lrcPath = lyricPatg;
    const response = await fetch(lrcPath);
    const lrcText = await response.text();

    lyricsPlayer.parseLyrics(lrcText);
    lyricsPlayer.update();

  } catch (error) {
    console.error('Error loading lyrics:', error);
    document.getElementById('lyrics-display').textContent =
        'Lyrics not available';
  }
}

document.getElementById('minimize')
    .addEventListener('click', () => {window.electronAPI.minimizeWindow()})

document.getElementById('maximize')
    .addEventListener('click', () => {window.electronAPI.toggleWindow()})

document.getElementById('close').addEventListener(
    'click', () => {window.electronAPI.closeWindow()})

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${
      secs.toString().padStart(2, '0')}`;
}

function updateTimeDisplay() {
  const currentTime = audioPlayer.currentTime;
  const duration = audioPlayer.duration || 0;
  timeDisplay.textContent =
      `${formatTime(currentTime)} / ${formatTime(duration)}`;

  if (duration > 0) {
    const progress = (currentTime / duration) * 100;
    progressBar.value = progress;
    lyricsPlayer.update();
  }
}

selectFileBtn.addEventListener('click', async () => {
  const filePaths = await window.electronAPI.openFileDialog();

  if (filePaths && filePaths.length > 0) {
    const filePath = filePaths[0];
    fileInfoDiv.textContent = `当前文件: ${filePath}`;
    audioPlayer.src = `file://${filePath}`;

    loadLyricsForSong(filePath.replace(/\.[^/.]+$/, '.lrc'));

    playBtn.disabled = false;
    pauseBtn.disabled = false;
    stopBtn.disabled = false;
  }
});

playBtn.addEventListener('click', () => {
  audioPlayer.play();
  window.electronAPI.sendPlayerCommand('play');
});

pauseBtn.addEventListener('click', () => {
  audioPlayer.pause();
  window.electronAPI.sendPlayerCommand('pause');
});

stopBtn.addEventListener('click', () => {
  audioPlayer.pause();
  audioPlayer.currentTime = 0;
  window.electronAPI.sendPlayerCommand('stop');
});

volumeSlider.addEventListener('input', () => {
  audioPlayer.volume = volumeSlider.value;
  window.electronAPI.setVolume(volumeSlider.value);
});

progressBar.addEventListener('input', () => {
  if (audioPlayer.duration) {
    const seekTime = (progressBar.value / 100) * audioPlayer.duration;
    audioPlayer.currentTime = seekTime;
  }
});

audioPlayer.addEventListener('timeupdate', updateTimeDisplay);

audioPlayer.addEventListener('ended', () => {
  audioPlayer.currentTime = 0;
  updateTimeDisplay();
  window.electronAPI.sendPlayerCommand('stopped');
});

audioPlayer.volume = volumeSlider.value;

window.electronAPI.onPlayerControl((command) => {
  console.log('Received player command:', command);
});

window.electronAPI.onVolumeChanged((volume) => {
  console.log('Volume changed to:', volume);
});
