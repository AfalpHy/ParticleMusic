const audioPlayer = document.getElementById('audio-player');
audioPlayer.volume = 0.3;

let lyricBodyActive = false;

class LyricsPlayer {
  constructor() {
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
    if (lyricBodyActive)
      currentLineElement.scrollIntoView({behavior: 'smooth', block: 'center'});
  }
}

const lyricsPlayer = new LyricsPlayer();

let playlist = [];

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
class PlaybackQueue {
  constructor() {
    this.play = false;
    this.empty = true;
    this.metadatas = [];
    this.currentMetadata = [];
    this.currentIndex = 0;
  }

  load() {
    this.currentMetadata = this.metadatas[this.currentIndex];
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
      if (playlist[element.children[0].textContent - 1].filePath ==
          this.currentMetadata.filePath) {
        element.style.background = 'rgba(220, 220, 220, 0.5)';
      } else {
        element.style.background = 'none';
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
}

const playbackQueue = new PlaybackQueue();

document.querySelectorAll('.minimize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.minimizeWindow()})});

document.querySelectorAll('.maximize')
    .forEach(
        element => {element.addEventListener(
            'click', () => {window.electronAPI.resizeWindow()})});

window.electronAPI.maximize(() => {
  document.querySelectorAll('.maximize').forEach(element => {
    element.style.backgroundImage = 'url(\'pictures/unmaximize.png\')';
  });
})

window.electronAPI.unmaximize(() => {
  document.querySelectorAll('.maximize').forEach(element => {
    element.style.backgroundImage = 'url(\'pictures/maximize.png\')';
  });
})

document.querySelectorAll('.close').forEach(
    element => {element.addEventListener(
        'click', () => {window.electronAPI.closeWindow()})});

const lyricsBody = document.getElementById('lyrics-body');

let timeOut;
lyricsBody.addEventListener('mousemove', () => {
  if (lyricBodyActive) {
    clearTimeout(timeOut);
    document.querySelectorAll('.custom-title-bar')[1].classList.remove(
        'hidden');
    document.getElementById('vice-music-controls').classList.remove('hidden');
    timeOut = setTimeout(() => {
      document.querySelectorAll('.custom-title-bar')[1].classList.add('hidden');
      document.getElementById('vice-music-controls').classList.add('hidden');
    }, 5000);
  }
});

document.getElementById('pull').addEventListener('click', () => {
  lyricBodyActive = false;
  lyricsBody.classList.remove('visible');
  clearTimeout(timeOut);
});

let fullScreen = false;
document.getElementById('full-screen').addEventListener('click', () => {
  fullScreen = !fullScreen;
  if (fullScreen) {
    document.getElementById('pull').style.visibility = 'hidden';
    document.getElementById('full-screen').classList.add('change');
    document.querySelectorAll('.window-controls')[1].style.visibility =
        'hidden';
    window.electronAPI.enterFullScreen();
  } else {
    document.getElementById('pull').style.visibility = 'visible';
    document.getElementById('full-screen').classList.remove('change');
    document.querySelectorAll('.window-controls')[1].style.visibility =
        'visible';
    window.electronAPI.leaveFullScreen();
  }
});

const resizer1 = document.getElementById('resizer1');
const resizer2 = document.getElementById('resizer2');
const songTtile = document.querySelector('.song-title');
const artist = document.querySelector('.artist');
const album = document.querySelector('.album');

let isDragging1 = false;
let isDragging2 = false;
let totalWidth;
resizer1.addEventListener('mousedown', (e) => {
  isDragging1 = true;
  totalWidth = songTtile.offsetWidth + artist.offsetWidth;
});

resizer2.addEventListener('mousedown', (e) => {
  isDragging2 = true;
  totalWidth = artist.offsetWidth + album.offsetWidth;
});

document.addEventListener('mousemove', (e) => {
  if (isDragging1) {
    const containerOffsetLeft = songTtile.getBoundingClientRect().left;
    const leftCurrentWidth = e.clientX - containerOffsetLeft;
    const containerWidth = songTtile.parentNode.offsetWidth;

    const leftPercent = (leftCurrentWidth / containerWidth) * 100;
    const rightPercent = (totalWidth - leftCurrentWidth) / containerWidth * 100;
    if (leftPercent < 10 || rightPercent < 10) {
      return;
    }

    document.querySelectorAll('.song-title')
        .forEach(element => element.style.flex = `0 0 ${leftPercent}%`)
    document.querySelectorAll('.artist').forEach(
        element => element.style.flex = `0 0 ${rightPercent}%`);
  }

  if (isDragging2) {
    const containerOffsetLeft = artist.getBoundingClientRect().left;
    const leftCurrentWidth = e.clientX - containerOffsetLeft;
    const containerWidth = artist.parentNode.offsetWidth;

    const leftPercent = (leftCurrentWidth / containerWidth) * 100;
    const rightPercent = (totalWidth - leftCurrentWidth) / containerWidth * 100;
    if (leftPercent < 10 || rightPercent < 10) {
      return;
    }

    document.querySelectorAll('.artist').forEach(
        element => element.style.flex = `0 0 ${leftPercent}%`)
    document.querySelectorAll('.album').forEach(
        element => element.style.flex = `0 0 ${rightPercent}%`);
  }
});

document.addEventListener('mouseup', () => {
  isDragging1 = false;
  isDragging2 = false;
});

function isAlphaNumeric(str) {
  return /^[A-Za-z0-9]+$/.test(str);
}

function compare(textA, textB) {
  if (isAlphaNumeric(textA[0])) {
    if (isAlphaNumeric(textB[0])) {
      return textA.localeCompare(textB);
    } else {
      return -1;
    }
  } else {
    if (isAlphaNumeric(textB[0])) {
      return 1;
    } else {
      return textA.localeCompare(textB, 'zh', {sensitivity: 'accent'});
    }
  }
}
function sortSongList(category, ascending) {
  const songs = document.getElementById('songs');
  const sorted = Array.from(songs.children).sort((a, b) => {
    const textA = a.children[category].textContent.trim()
    const textB = b.children[category].textContent.trim();
    if (ascending) {
      return compare(textA, textB);
    } else {
      return compare(textB, textA);
    }
  });
  let i = 1;
  let newPlaylist = [];
  sorted.forEach(element => {
    const index = element.children[0].textContent - 1;
    newPlaylist.push(playlist[index]);
    element.children[0].textContent = i++;
    songs.appendChild(element);
  });
  playlist = newPlaylist;
}

let songTtileAscending = false;
let artistAscending = false;
let albumAscending = false;
let durationAscending = false;
songTtile.addEventListener('click', () => {
  if (loadingPlaylist) {
    return;
  }
  songTtileAscending = !songTtileAscending;
  sortSongList(1, songTtileAscending);
  // reset others
  artistAscending = false;
  albumAscending = false;
  durationAscending = false;
});

artist.addEventListener('click', () => {
  if (loadingPlaylist) {
    return;
  }
  artistAscending = !artistAscending;
  sortSongList(2, artistAscending);
  songTtileAscending = false;
  albumAscending = false;
  durationAscending = false;
});


album.addEventListener('click', () => {
  if (loadingPlaylist) {
    return;
  }
  albumAscending = !albumAscending;
  sortSongList(3, albumAscending);
  songTtileAscending = false;
  artistAscending = false;
  durationAscending = false;
});

document.querySelector('.duration').addEventListener('click', () => {
  if (loadingPlaylist) {
    return;
  }
  durationAscending = !durationAscending;
  sortSongList(4, durationAscending);
  songTtileAscending = false;
  artistAscending = false;
  albumAscending = false;
});


function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${
      secs.toString().padStart(2, '0')}`;
}

let metaIndex = 1;
window.electronAPI.addSongToList((metadata) => {
  playlist.push(metadata);
  message = [
    metaIndex++, metadata.title, metadata.artist, metadata.album,
    formatTime(metadata.duration)
  ];
  const songLabelChidren = document.getElementById('song-label').children;

  const lineElement = document.createElement('div');
  lineElement.className = 'song-line';

  for (let i = 0; i < message.length; i++) {
    const columnElement = document.createElement('div');
    columnElement.className = songLabelChidren[i].className;
    columnElement.style.flex = songLabelChidren[i].style.flex;
    columnElement.style.overflow = 'hidden';

    const columnElementText = document.createElement('div');
    columnElementText.className = 'song-line-column-text'
    columnElementText.textContent = message[i];
    columnElement.append(columnElementText);
    lineElement.append(columnElement);
  }

  document.getElementById('songs').append(lineElement);

  lineElement.addEventListener('dblclick', () => {
    if (loadingPlaylist) {
      return;
    }
    playbackQueue.empty = false;
    playbackQueue.metadatas = playlist;
    playbackQueue.currentIndex =
        parseInt(lineElement.children[0].textContent) - 1;
    playbackQueue.load();
    playbackQueue.play = true;
    playbackQueue.playOrPause();
  });
})

let loadingPlaylist = false;
document.getElementById('playlist').addEventListener('click', () => {
  if (loadingPlaylist) {
    return;
  }
  loadingPlaylist = true;
  document.getElementById('cover').classList.add('hidden');
  document.getElementById('song-list').classList.add('visible');

  // reset
  const songs = document.getElementById('songs');
  songs.innerHTML = '';
  playlist = [];
  metaIndex = 1;

  window.electronAPI
      .loadPlaylist(document.getElementById('playlist').textContent)
      .then(() => {
        loadingPlaylist = false;
      })
})

document.getElementById('title').addEventListener('click', () => {
  document.getElementById('cover').classList.remove('hidden');
  document.getElementById('song-list').classList.remove('visible');
})

document.getElementById('music-controls')
    .addEventListener('click', function(e) {
      if (e.target !== this) {
        return;  // Exit if click came from any child element
      }
      if (!lyricBodyActive) {
        lyricBodyActive = true;
        lyricsBody.classList.add('visible');
      }
    });

document.querySelectorAll('.last-btn')
    .forEach(element => {element.addEventListener('click', () => {
               if (!playbackQueue.empty) {
                 playbackQueue.last();
               }
             })});

document.querySelectorAll('.play-pause-btn')
    .forEach(element => {element.addEventListener('click', () => {
               if (!playbackQueue.empty) {
                 playbackQueue.play = !playbackQueue.play;
                 playbackQueue.playOrPause();
               }
             })});

document.querySelectorAll('.next-btn')
    .forEach(element => {element.addEventListener('click', () => {
               if (!playbackQueue.empty) {
                 playbackQueue.next();
               }
             })});



let isDraggingProcessBar = false;
const progressBarElements = document.querySelectorAll('.progress');
function updateProgressDisplay() {
  const currentTime = audioPlayer.currentTime;
  const duration = playbackQueue.currentMetadata.duration;
  const currentTimeElements = document.querySelectorAll('.current-time');
  const totalTimeElements = document.querySelectorAll('.total-time');
  currentTimeElements.forEach(element => {
    element.textContent = `${formatTime(currentTime)}`;
  });

  totalTimeElements.forEach(element => {
    element.textContent = `${formatTime(duration)}`;
  });

  if (duration > 0) {
    const progress = (currentTime / duration) * 100;
    if (!isDraggingProcessBar) {
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
    if (!playbackQueue.empty) element.classList.add('hover');
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mouseleave', () => {
    if (!playbackQueue.empty) element.classList.remove('hover');
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mousedown', () => {
    isDraggingProcessBar = true;
  });
})

progressBarElements.forEach(element => {
  element.addEventListener('mouseup', () => {
    isDraggingProcessBar = false;
    if (!playbackQueue.empty) {
      const seekTime =
          (element.value / 100) * playbackQueue.currentMetadata.duration;
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

let clickPlaybackQueueBtn = false;
let playbackQueueDisplay = false;
document.querySelectorAll('.playback-queue-btn')
    .forEach(element => element.addEventListener('click', () => {
      clickPlaybackQueueBtn = true;
      playbackQueueDisplay = !playbackQueueDisplay;
      if (playbackQueueDisplay)
        document.getElementById('playback-queue').classList.add('display');
      else
        document.getElementById('playback-queue').classList.remove('display');
    }));

document.addEventListener('click', (e) => {
  if (clickPlaybackQueueBtn) {
    clickPlaybackQueueBtn = false;
    return;
  }
  if (playbackQueueDisplay) {
    playbackQueueDisplay = false;
    document.getElementById('playback-queue').classList.remove('display');
  }
})

const volumeSlider = document.querySelectorAll('.volume');
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

audioPlayer.addEventListener('timeupdate', updateProgressDisplay);

audioPlayer.addEventListener('ended', () => {
  playbackQueue.next();
})
