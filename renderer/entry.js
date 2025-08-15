import './windowControls.js'
import './lyricPlaneControls.js'
import './songList.js'
import './sidebar.js'
import './musicControls.js'
import './playQueueControls.js'

import { lyricsPlane, playQueue, playQueueSongs, playQueueSongMenu, shared, songList, songMenu } from './shared.js'
import { activeLyricsPlane, changeFullScreenMode, pullLyricsPlane, setControlsHiddenTimeout } from './lyricPlaneControls.js'
import { displayPlayQueue, hiddenPlayQueue, playQueueEvent, playQueueSongMemuEvent } from './playQueueControls.js'
import { displayCover, displaySongList } from './sidebar.js'
import { switchMute } from './musicControls.js'
import { dblclickSong, enableResizer1, enableResizer2, searchList, songMemuEvent, sortSongByAlbum, sortSongByArtist, sortSongByDuration, sortSongByTitle } from './songList.js'

const playQueuePlane = document.getElementById('play-queue');

document.addEventListener('click', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);

    if (shared.playQueueDisplay) {
        if (playQueueSongMenu.contains(e.target)) {
            playQueueSongMemuEvent(e.target);
            return;
        }
        playQueueSongMenu.style.visibility = 'hidden';
        if (playQueuePlane.contains(e.target)) {
            playQueueEvent(e.target);
            return;
        }
        hiddenPlayQueue();
        return;
    }

    if (songMenu.contains(e.target)) {
        songMemuEvent(e.target);
        return;
    }
    songMenu.style.visibility = 'hidden';

    if (lyricsPlane.contains(e.target)) {
        setControlsHiddenTimeout();
    }

    if (id == 'title') {
        displayCover();
    } else if (id == 'playlist') {
        displaySongList();
    } else if (className == 'minimize') {
        window.electronAPI.minimizeWindow();
    } else if (className == 'maximize') {
        window.electronAPI.resizeWindow();
    } else if (className == 'close') {
        window.electronAPI.closeWindow();
    } else if (id == 'pull' || id == 'vice-music-controls') {
        pullLyricsPlane();
    } else if (id == 'full-screen') {
        changeFullScreenMode();
    } else if (id == 'song-title-label') {
        sortSongByTitle();
    } else if (id == 'artist-label') {
        sortSongByArtist();
    } else if (id == 'album-label') {
        sortSongByAlbum();
    } else if (id == 'duration-label') {
        sortSongByDuration();
    } else if (id == 'music-controls') {
        activeLyricsPlane();
    } else if (className == 'last-btn') {
        if (!playQueue.empty) {
            playQueue.last();
        }
    } else if (className == 'play-pause-btn') {
        if (!playQueue.empty) {
            playQueue.play = !playQueue.play;
            playQueue.playOrPause();
        }
    } else if (className == 'next-btn') {
        if (!playQueue.empty) {
            playQueue.next();
        }
    } else if (className == 'play-mode-btn') {
        playQueue.switchPlayMode();
    } else if (className == 'play-queue-btn') {
        displayPlayQueue();
    } else if (className == 'volume-icon') {
        switchMute();
    }
})

document.addEventListener('dblclick', (e) => {
    if (searchList.contains(e.target) && !searchList.children[0].contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.originIndex - 1);
    } else if (songList.contains(e.target) && !songList.children[0].contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.children[0].textContent - 1);
    }
})

document.addEventListener('mousedown', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);
    if (e.button == 2) {
        if (!songMenu.contains(e.target)) {
            songMenu.style.visibility = 'hidden';
        }
        if (shared.playQueueDisplay) {
            if (!playQueueSongMenu.contains(e.target)) {
                playQueueSongMenu.style.visibility = 'hidden';
            } else {
                return;
            }
            if (playQueuePlane.contains(e.target)) {
                if (playQueueSongs.contains(e.target)) {
                    let tmp = e.target;
                    while (tmp && tmp.className != 'play-queue-song-line') {
                        tmp = tmp.parentNode;
                    }
                    if (!tmp) {
                        return;
                    }
                    let index = 0;
                    while ((tmp = tmp.previousElementSibling) != null) {
                        index++;
                    }
                    shared.clickPlayQueueSongIndex = index;
                    playQueueSongMenu.style.visibility = 'visible';
                    playQueueSongMenu.style.left = e.pageX + 'px';
                    playQueueSongMenu.style.top = e.pageY + 'px';
                }
                return;
            }
            hiddenPlayQueue();
            return;
        }

        if (searchList.contains(e.target) && !searchList.children[0].contains(e.target)) {
            let tmp = e.target;
            while (tmp.className != 'song-line') {
                tmp = tmp.parentNode;
            }
            shared.clickSongIndex = tmp.originIndex;
            songMenu.style.visibility = 'visible';
            songMenu.style.left = e.pageX + 'px';
            songMenu.style.top = e.pageY + 'px';
        } else if (songList.contains(e.target) && !songList.children[0].contains(e.target)) {
            let tmp = e.target;
            while (tmp.className != 'song-line') {
                tmp = tmp.parentNode;
            }
            shared.clickSongIndex = tmp.children[0].textContent;
            songMenu.style.visibility = 'visible';
            songMenu.style.left = e.pageX + 'px';
            songMenu.style.top = e.pageY + 'px';
        }
        return;
    }
    if (shared.playQueueDisplay) {
        return;
    }
    if (id == 'resizer1') {
        enableResizer1();
    } else if (id == 'resizer2') {
        enableResizer2();
    }
})
