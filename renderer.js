const lastBtn = document.getElementById('lastBtn');
const playOrStopBtn = document.getElementById('playOrStopBtn');
const nextBtn = document.getElementById('nextBtn');
const volumeSlider = document.getElementById('volume');
const audioPlayer = document.getElementById('audioPlayer');
const timeDisplay = document.getElementById('timeDisplay');
const progressBar = document.getElementById('progress');

let songPaths = [];
let songBaseNames = [];
let songIndex = 0;

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

document.querySelectorAll('.minimize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.minimizeWindow()})});

document.querySelectorAll('.maximize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.toggleWindow()})});

document.querySelectorAll('.close').forEach(
    element => {element.addEventListener(
        'click', () => {window.electronAPI.closeWindow()})});


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

lastBtn.addEventListener('click', () => {
  audioPlayer.pause();
  if (songIndex > 0) songIndex -= 1;
  audioPlayer.src = `file://${songPaths[songIndex]}`;
  loadLyricsForSong(songPaths[songIndex].replace(/\.[^/.]+$/, '.lrc'));
  audioPlayer.currentTime = 0;
  if (playOrStopBtn.textContent == '暂停') {
    audioPlayer.play();
  }

  updateTimeDisplay();
});


playOrStopBtn.addEventListener('click', () => {
  if (playOrStopBtn.textContent == '播放') {
    playOrStopBtn.textContent = '暂停';
    document.getElementById('lyrics-body').classList.add('visible');
    audioPlayer.play();
  } else {
    playOrStopBtn.textContent = '播放';
    audioPlayer.pause();
  }
  updateTimeDisplay();
});

nextBtn.addEventListener('click', () => {
  audioPlayer.pause();
  if (songIndex < songPaths.length - 1) songIndex += 1;
  audioPlayer.src = `file://${songPaths[songIndex]}`;
  loadLyricsForSong(songPaths[songIndex].replace(/\.[^/.]+$/, '.lrc'));
  audioPlayer.currentTime = 0;
  if (playOrStopBtn.textContent == '暂停') {
    audioPlayer.play();
  }
  updateTimeDisplay();
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
  songIndex += 1;
  songIndex %= songPaths.length;
  audioPlayer.src = `file://${songPaths[songIndex]}`;
  loadLyricsForSong(songPaths[songIndex].replace(/\.[^/.]+$/, '.lrc'));
  audioPlayer.play();
  updateTimeDisplay();
});

audioPlayer.volume = volumeSlider.value;

window.electronAPI.receiveInitialSongs((songs, songBases) => {
  songPaths = songs;
  songBaseNames = songBases;
  audioPlayer.src = `file://${songPaths[0]}`;
  loadLyricsForSong(songPaths[songIndex].replace(/\.[^/.]+$/, '.lrc'));
  audioPlayer.currentTime = 0;
  for (let i = 0; i < songBases.length; i++) {
    const lineElement = document.createElement('div');
    lineElement.className = 'file-line';
    lineElement.textContent = songBases[i];
    document.getElementById('leftbody').appendChild(lineElement);
    lineElement.addEventListener('dblclick', () => {
      for (let i = 0; i < songBaseNames.length; i++) {
        if (lineElement.textContent == songBaseNames[i]) {
          songIndex = i;
          break;
        }
      }
      audioPlayer.src = `file://${songPaths[songIndex]}`;
      loadLyricsForSong(songPaths[songIndex].replace(/\.[^/.]+$/, '.lrc'));
      audioPlayer.play();
      playOrStopBtn.textContent = '暂停';
    });
  }
});
