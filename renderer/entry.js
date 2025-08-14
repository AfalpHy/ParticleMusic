import './windowControls.js'
import './lyricPlaneControls.js'
import './songList.js'
import './sidebar.js'
import './musicControls.js'
import './playbackQueueControls.js'

import { lyricsPlane, playbackQueue, shared, songList } from './shared.js'
import { activeLyricsPlane, changeFullScreenMode, pullLyricsPlane, setControlsHiddenTimeout } from './lyricPlaneControls.js'
import { displayPlaybackQueue, hiddenPlaybackQueue, playbackQueueEvent } from './playbackQueueControls.js'
import { displayCover, displaySongList } from './sidebar.js'
import { switchMute } from './musicControls.js'
import { dblclickSong, enableResizer1, enableResizer2, searchList, sortSongByAlbum, sortSongByArtist, sortSongByDuration, sortSongByTitle } from './songList.js'

const playbackQueuePlane = document.getElementById('playback-queue');

document.addEventListener('click', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);
    if (shared.playbackQueueDisplay) {
        if (playbackQueuePlane.contains(e.target)) {
            playbackQueueEvent(e.target);
            return;
        }
        hiddenPlaybackQueue();
        return;
    }
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
        if (!playbackQueue.empty) {
            playbackQueue.last();
        }
    } else if (className == 'play-pause-btn') {
        if (!playbackQueue.empty) {
            playbackQueue.play = !playbackQueue.play;
            playbackQueue.playOrPause();
        }
    } else if (className == 'next-btn') {
        if (!playbackQueue.empty) {
            playbackQueue.next();
        }
    } else if (className == 'play-mode-btn') {
        playbackQueue.switchPlayMode();
    } else if (className == 'playback-queue-btn') {
        displayPlaybackQueue();
    } else if (className == 'volume-icon') {
        switchMute();
    }
})

document.addEventListener('dblclick', (e) => {
    if (searchList.contains(e.target) && !searchList.firstChild.contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.originIndex - 1);
    } else if (songList.contains(e.target) && !songList.firstChild.contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.firstChild.textContent - 1);
    }
})

document.addEventListener('mousedown', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);
    if (shared.playbackQueueDisplay) {
        return;
    }
    if (id == 'resizer1') {
        enableResizer1();
    } else if (id == 'resizer2') {
        enableResizer2();
    }
})
