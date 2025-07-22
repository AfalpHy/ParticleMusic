document.querySelectorAll('.minimize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.minimizeWindow()})});

document.querySelectorAll('.maximize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.resizeWindow()})});

document.querySelectorAll('.close').forEach(
    element => {element.addEventListener(
        'click', () => {window.electronAPI.closeWindow()})});

const volumeSlider = document.querySelectorAll('.volume');
const audioPlayer = document.getElementById('audio-player');
const currentTimeElements = document.querySelectorAll('.current-time');
const totalTimeElements = document.querySelectorAll('.total-time');
const progressBarElements = document.querySelectorAll('.progress');
const lyricsBody = document.getElementById('lyrics-body');

let timeOut;
lyricsBody.addEventListener('mousemove', () => {
  clearTimeout(timeOut);
  document.querySelectorAll('.custom-title-bar')[1].classList.remove('hidden');
  document.getElementById('vice-music-controls').classList.remove('hidden');
  timeOut = setTimeout(() => {
    document.querySelectorAll('.custom-title-bar')[1].classList.add('hidden');
    document.getElementById('vice-music-controls').classList.add('hidden');
  }, 5000);
});

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
    this.duration = [];
    this.songIndex = 0;
  }

  load() {
    let src = `file://${this.songPaths[this.songIndex]}`;
    audioPlayer.src = src;
    loadLyricsForSong(src.replace(/\.[^/.]+$/, '.lrc'));
    audioPlayer.currentTime = 0;
    updateTimeDisplay();
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
    document.querySelectorAll('.song-line').forEach(element => {
      if (element.children[0].textContent == this.songIndex) {
        element.style.background = 'rgba(220, 220, 220, 0.5)';
      } else {
        element.style.background = 'none';
      }
    })
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
               if (playlist.songPaths.length) {
                 playlist.last();
               }
             })});

document.querySelectorAll('.play-pause-btn')
    .forEach(element => {element.addEventListener('click', () => {
               if (playlist.songPaths.length) {
                 playlist.play = !playlist.play;
                 playlist.playOrPause();
               }
             })});

document.querySelectorAll('.next-btn')
    .forEach(element => {element.addEventListener('click', () => {
               if (playlist.songPaths.length) {
                 playlist.next();
               }
             })});

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${
      secs.toString().padStart(2, '0')}`;
}

function toSecond(timeStr) {
  const parts = timeStr.split(':').map(Number);
  if (parts.length === 2) {
    // MM:SS
    return parts[0] * 60 + parts[1];
  } else {
    throw new Error('Invalid time format');
  }
}

let paintWhenUpdateTime = true;
function updateTimeDisplay() {
  const currentTime = audioPlayer.currentTime;
  const duration =
      playlist.songPaths.length ? playlist.duration[playlist.songIndex] : 0;
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
    if (playlist.songPaths.length) element.classList.add('hover');
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mouseleave', () => {
    if (playlist.songPaths.length) element.classList.remove('hover');
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
    if (playlist.songPaths.length) {
      const seekTime =
          (element.value / 100) * playlist.duration[playlist.songIndex];
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

function adjustVolume(value) {
  if (value) {
    document.querySelectorAll('.volume-icon').forEach(element => {
      element.style.backgroundImage = 'url(\'pictures/speaker.png\')';
    });
  } else {
    document.querySelectorAll('.volume-icon').forEach(element => {
      element.style.backgroundImage = 'url(\'pictures/speaker-mute.png\')';
    });
  }
  audioPlayer.volume = value;
  volumeSlider.forEach(
    element => {
      element.value = audioPlayer.volume * 100
      element.style.background =
      `linear-gradient(to right, black 0%, black ${
        element.value}%, #d3d3d3 ${element.value}%, #d3d3d3 100%)`});
}


let tempVolume = volumeSlider[0].value;
volumeSlider.forEach(element => element.addEventListener('input', () => {
  tempVolume = element.value;
  adjustVolume(element.value / 100);
}));

document.querySelectorAll('.volume-icon')
    .forEach(element => {element.addEventListener('click', () => {
               if (volumeSlider[0].value != 0) {
                 adjustVolume(0);
               } else {
                 adjustVolume(tempVolume / 100);
               }
             })});

audioPlayer.addEventListener('timeupdate', updateTimeDisplay);

window.electronAPI.receiveInitialSongs((songPaths, songBases) => {
  playlist.songPaths = songPaths;
  playlist.songBaseNames = songBases;
  playlist.load();
});

window.electronAPI.addCorner(() => {
  document.getElementById('entire-body').classList.add('corner');
  document.getElementById('sidebar').classList.add('adjustSize');
  document.getElementById('main-body').classList.add('adjustSize');
  document.querySelectorAll('.maximize').forEach(element => {
    element.style.backgroundImage = 'url(\'pictures/unmaximize.png\')';
  });
})

window.electronAPI.removeCorner(() => {
  document.getElementById('entire-body').classList.remove('corner');
  document.getElementById('sidebar').classList.remove('adjustSize');
  document.getElementById('main-body').classList.remove('adjustSize');
  document.querySelectorAll('.maximize').forEach(element => {
    element.style.backgroundImage = 'url(\'pictures/maximize.png\')';
  });
})

let metaIndex = 0;
window.electronAPI.addSong((metadata) => {
  const message =
      [metadata.title, metadata.artist, metadata.album, metadata.duration];
  playlist.duration.push(toSecond(metadata.duration));
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
    playlist.songIndex = parseInt(lineElement.children[0].textContent);
    playlist.load();
    playlist.play = true;
    playlist.playOrPause();
  });
})