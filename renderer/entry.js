import './windowControls.js'
import './lyricPlaneControls.js'
import './songList.js'
import './sidebar.js'
import './musicControls.js'
import './playQueueControls.js'

import { lyricsPlane, player, playQueue, playQueueSongMenu, shared, songList, songMenu, sideBar, viceMusicControls, lyricPlaneCustomTitleBar, playQueuePlane } from './shared.js'
import { activeLyricsPlane, changeFullScreenMode, pullLyricsPlane, setControlsHiddenTimeout } from './lyricPlaneControls.js'
import { displayPlayQueuePlane, hiddenPlayQueuePlane, playQueueEvent, playQueueSongMemuEvent } from './playQueueControls.js'
import { displayCover, displaySongList } from './sidebar.js'
import { switchMute } from './musicControls.js'
import { dblclickSong, enableResizer1, enableResizer2, searchSongList, songMemuEvent, sortSongByAlbum, sortSongByArtist, sortSongByDuration, sortSongByTitle } from './songList.js'

let searchTyping = false;
document.addEventListener('click', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);

    if (id == 'search') {
        searchTyping = true;
    } else {
        searchTyping = false;
        // remove focus
        e.target.blur();
    }

    if (songMenu.contains(e.target)) {
        songMemuEvent(e.target);
        return;
    }

    if (playQueueSongMenu.contains(e.target)) {
        playQueueSongMemuEvent(e.target);
        return;
    }

    if (playQueuePlane.contains(e.target)) {
        playQueueEvent(e.target);
        return;
    }

    if (lyricsPlane.contains(e.target)) {
        setControlsHiddenTimeout();
        if (shared.playQueueDisplay) {
            if (!viceMusicControls.contains(e.target) && !lyricPlaneCustomTitleBar.contains(e.target)) {
                hiddenPlayQueuePlane();
                return;
            }
        }
    }

    if (shared.playQueueDisplay) {
        if (sideBar.contains(e.target) || id == 'music-controls' || id == 'pull' || id == 'full-screen' || id == 'vice-music-controls') {
            hiddenPlayQueuePlane();
            return;
        }
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
        if (!player.empty) {
            player.last();
        }
    } else if (className == 'play-pause-btn') {
        if (player.currentSong) {
            player.play = !player.play;
            player.playOrPause();
        }
    } else if (className == 'next-btn') {
        if (!player.empty) {
            player.next();
        }
    } else if (className == 'play-mode-btn') {
        player.switchPlayMode();
    } else if (className == 'play-queue-btn') {
        if (shared.playQueueDisplay) {
            hiddenPlayQueuePlane();
        } else {
            displayPlayQueuePlane();
        }
    } else if (className == 'speaker') {
        switchMute();
    }
})

document.addEventListener('dblclick', (e) => {
    if (searchSongList.contains(e.target) && !searchSongList.children[0].contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.children[0].textContent - 1, false);
    } else if (songList.contains(e.target) && !songList.children[0].contains(e.target)) {
        let tmp = e.target;
        while (tmp.className != 'song-line') {
            tmp = tmp.parentNode;
        }
        dblclickSong(tmp.children[0].textContent - 1, true);
    }
})

document.addEventListener('mousedown', (e) => {
    const className = e.target.className;
    const id = e.target.id;
    // console.log(className, id);
    if (!songMenu.contains(e.target)) {
        songMenu.style.visibility = 'hidden';
    }

    if (!playQueueSongMenu.contains(e.target)) {
        playQueueSongMenu.style.visibility = 'hidden';
    }

    if (e.button == 2) {
        if (playQueue.contains(e.target)) {
            let tmp = e.target;
            while (tmp && tmp.className != 'play-queue-line') {
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

        if (searchSongList.contains(e.target) && !searchSongList.children[0].contains(e.target)) {
            let tmp = e.target;
            while (tmp && tmp.className != 'song-line') {
                tmp = tmp.parentNode;
            }
            if (!tmp) {
                return;
            }
            shared.clickSongIndex = tmp.originIndex;
            songMenu.style.visibility = 'visible';
            songMenu.style.left = e.pageX + 'px';
            songMenu.style.top = e.pageY + 'px';
        } else if (songList.contains(e.target) && !songList.children[0].contains(e.target)) {
            let tmp = e.target;
            while (tmp && tmp.className != 'song-line') {
                tmp = tmp.parentNode;
            }
            if (!tmp) {
                return;
            }
            shared.clickSongIndex = tmp.children[0].textContent;
            songMenu.style.visibility = 'visible';
            songMenu.style.left = e.pageX + 'px';
            songMenu.style.top = e.pageY + 'px';
        }
        return;
    }

    if (id == 'resizer1') {
        enableResizer1();
    } else if (id == 'resizer2') {
        enableResizer2();
    }
})

document.addEventListener('keydown', function (event) {
    if (event.key === ' ') {
        if (searchTyping) {
            return;
        }
        event.preventDefault();
        if (player.currentSong) {
            player.play = !player.play;
            player.playOrPause();
        }
    }
});

