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

const volumeSlider = document.querySelectorAll('.volume');
const audioPlayer = document.getElementById('audio-player');
const currentTimeElements = document.querySelectorAll('.current-time');
const totalTimeElements = document.querySelectorAll('.total-time');
const progressBarElements = document.querySelectorAll('.progress');
const lyricsBody = document.getElementById('lyrics-body');

document.getElementById('pull').addEventListener('click', () => {
  lyricsPlayer.active = false;
  lyricsBody.classList.remove('visible');
});

audioPlayer.volume = volumeSlider[0].value / 100;

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

document.getElementById('music-controls')
    .addEventListener('click', function(e) {
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

document.querySelectorAll('.last-btn')
    .forEach(element => {element.addEventListener('click', () => {
               playlist.last();
             })});

document.querySelectorAll('.play-pause-btn')
    .forEach(element => {element.addEventListener('click', () => {
               playlist.play = !playlist.play;
               playlist.playOrPause();
             })});

document.querySelectorAll('.next-btn')
    .forEach(element => {element.addEventListener('click', () => {
               playlist.next();
             })});

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${
      secs.toString().padStart(2, '0')}`;
}

let paintWhenUpdateTime = true;
function updateTimeDisplay() {
  const currentTime = audioPlayer.currentTime;
  const duration = audioPlayer.duration || 0;
  currentTimeElements.forEach(element => {
    element.textContent = `${formatTime(currentTime)}`;
  });

  totalTimeElements.forEach(element => {
    element.textContent = `${formatTime(duration)}`;
  });

  if (duration > 0) {
    const progress = (currentTime / duration) * 100;
    if (paintWhenUpdateTime) {
      progressBarElements.forEach(element => {
        element.style.background = `linear-gradient(to right, black 0%, black ${
            progress}%, #d3d3d3 ${progress}%, #d3d3d3 100%)`;
        element.value = progress;
      })
    }

    lyricsPlayer.update();
  }
}

progressBarElements.forEach(element => {
  element.addEventListener('mouseenter', () => {
    element.classList.add('hover');
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mouseleave', () => {
    element.classList.remove('hover');
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mousedown', () => {
    paintWhenUpdateTime = false;
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mouseup', () => {
    paintWhenUpdateTime = true;
    if (audioPlayer.duration) {
      const seekTime = (element.value / 100) * audioPlayer.duration;
      audioPlayer.currentTime = seekTime;
    }
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('input', () => {
    const progress = element.value;
    element.style.background = `linear-gradient(to right, black 0%, black ${
        progress}%, #d3d3d3 ${progress}%, #d3d3d3 100%)`;
  });
})


volumeSlider.forEach(element => {
  element.addEventListener('mouseenter', () => {
    element.classList.add('hover');
  });
})

volumeSlider.forEach(element => {
  element.addEventListener('mouseleave', () => {
    element.classList.remove('hover');
  });
})

volumeSlider.forEach(element => element.addEventListener('input', () => {
  audioPlayer.volume = element.value / 100;
  volumeSlider.forEach(
    element => {
      element.value = audioPlayer.volume * 100
      element.style.background =
      `linear-gradient(to right, black 0%, black ${
        element.value}%, #d3d3d3 ${element.value}%, #d3d3d3 100%)`})
}));

audioPlayer.addEventListener('timeupdate', updateTimeDisplay);

window.electronAPI.receiveInitialSongs((songPaths, songBases) => {
  playlist.songPaths = songPaths;
  playlist.songBaseNames = songBases;
  playlist.load();
});

window.electronAPI.addCorner(() => {
  document.getElementById('entire-body').classList.add('corner');
})

window.electronAPI.removeCorner(() => {
  document.getElementById('entire-body').classList.remove('corner');
})

let metaIndex = 0;
window.electronAPI.addSong((metadata) => {
  const message =
      [metadata.title, metadata.artist, metadata.album, metadata.duration];
  const songs = document.getElementById('songs');
  const lineElement = document.createElement('div');
  lineElement.className = 'song-line';
  const columnElement = document.createElement('div');
  columnElement.textContent = metaIndex++;
  lineElement.append(columnElement);
  for (let i = 0; i < message.length; i++) {
    const columnElement = document.createElement('div');
    columnElement.textContent = message[i];
    lineElement.append(columnElement);
  }
  songs.append(lineElement);
  lineElement.addEventListener('dblclick', () => {
    playlist.songIndex = lineElement.children[0].textContent;
    playlist.load();
    playlist.play = true;
    playlist.playOrPause();
  });
})