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

const lastBtn = document.getElementById('last-btn');
const playPauseBtn = document.getElementById('play-pause-btn');
const nextBtn = document.getElementById('next-btn');
const volumeSlider = document.getElementById('volume');
const audioPlayer = document.getElementById('audio-player');
const timeDisplay = document.getElementById('time-display');
const progressBar = document.getElementById('progress');
const lyricsBody = document.getElementById('lyrics-body');

document.getElementById('pull').addEventListener('click', () => {
  lyricsPlayer.active = false;
  lyricsBody.classList.remove('visible');
});


audioPlayer.volume = volumeSlider.value;

class Playlist {
  constructor() {
    this.play = false;
    this.songPaths = [];
    this.songBaseNames = [];
    this.songIndex = 0;
  }

  load() {
    let src = `file://${this.songPaths[this.songIndex]}`;
    audioPlayer.src = src;
    loadLyricsForSong(src.replace(/\.[^/.]+$/, '.lrc'));
    audioPlayer.currentTime = 0;
  }

  last() {
    audioPlayer.pause();
    this.songIndex += this.songPaths.length - 1;
    this.songIndex %= this.songPaths.length;
    this.load();

    this.playOrPause();
  }

  playOrPause() {
    if (this.play) {
      playPauseBtn.textContent = 'pause';
      audioPlayer.play();
    } else {
      playPauseBtn.textContent = 'play';
      audioPlayer.pause();
    }
  }

  next() {
    audioPlayer.pause();
    this.songIndex += 1;
    this.songIndex %= this.songPaths.length;
    this.load();
    this.playOrPause();
  }
}

const playlist = new Playlist();

document.getElementById('playlist').addEventListener('click', () => {
  window.electronAPI.getSongs();
})

document.querySelector('.container').addEventListener('click', function(e) {
  if (e.target !== this) {
    return;  // Exit if click came from any child element
  }
  if (!lyricsPlayer.active) {
    lyricsPlayer.active = true;
    lyricsBody.classList.add('visible');
  }
})

class LyricsPlayer {
  constructor() {
    this.active = false;
    this.lines = [];
    this.lineElements = [];
    this.container = document.getElementById('lyrics-display');
    this.currentLineIndex = -1;
  }

  // Parse LRC file content
  parseLyrics(lrcText) {
    this.container.innerHTML = '';
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

    this.lineElements = [];
    for (let lineIndex = 0; lineIndex < this.lines.length; lineIndex++) {
      const lineElement = document.createElement('div');
      lineElement.className = 'lyrics-line';
      lineElement.textContent = this.lines[lineIndex].text;
      this.lineElements.push(lineElement);
      this.container.appendChild(lineElement);
    }
    this.currentLineIndex = -1;
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
    if (this.active)
      currentLineElement.scrollIntoView({behavior: 'smooth', block: 'center'});
  }
}

const lyricsPlayer = new LyricsPlayer();

async function loadLyricsForSong(lyricPatg) {
  try {
    const lrcPath = lyricPatg;
    const response = await fetch(lrcPath);
    const lrcText = await response.text();

    lyricsPlayer.parseLyrics(lrcText);
  } catch (error) {
    console.error('Error loading lyrics:', error);
    document.getElementById('lyrics-display').textContent =
        'Lyrics not available';
  }
}

lastBtn.addEventListener('click', () => {
  playlist.last();
});

playPauseBtn.addEventListener('click', () => {
  playlist.play = !playlist.play;
  playlist.playOrPause();
});

nextBtn.addEventListener('click', () => {
  playlist.next();
});

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

progressBar.addEventListener('input', () => {
  if (audioPlayer.duration) {
    const seekTime = (progressBar.value / 100) * audioPlayer.duration;
    audioPlayer.currentTime = seekTime;
  }
});

volumeSlider.addEventListener('input', () => {
  audioPlayer.volume = volumeSlider.value;
  window.electronAPI.setVolume(volumeSlider.value);
});

audioPlayer.addEventListener('timeupdate', updateTimeDisplay);

window.electronAPI.receiveInitialSongs((songPaths, songBases) => {
  playlist.songPaths = songPaths;
  playlist.songBaseNames = songBases;
  playlist.load();

  for (let i = 0; i < songBases.length; i++) {
    const lineElement = document.createElement('div');
    lineElement.className = 'file-line';
    lineElement.textContent = songBases[i];
    lineElement.addEventListener('dblclick', () => {
      for (let i = 0; i < playlist.songBaseNames.length; i++) {
        if (lineElement.textContent == playlist.songBaseNames[i]) {
          playlist.songIndex = i;
          break;
        }
      }
      playlist.load();
      playlist.play = !playlist.play;
      playlist.playOrPause();
    });
    document.querySelector('.song-list').appendChild(lineElement);
  }
});

window.electronAPI.addCorner(() => {
  document.querySelector('.entire-body').classList.add('corner');
  lyricsBody.classList.add('corner');
})

window.electronAPI.removeCorner(() => {
  document.querySelector('.entire-body').classList.remove('corner');
  lyricsBody.classList.remove('corner');
})