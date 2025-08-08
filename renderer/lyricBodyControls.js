import { lyricsBody } from './shared.js';
import { shared } from './shared.js';

let timeOut;
lyricsBody.addEventListener('mousemove', () => {
    if (shared.lyricBodyActive) {
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
    // skip once
    if (shared.playbackQueueDisplay) {
        return;
    }
    shared.lyricBodyActive = false;
    lyricsBody.classList.remove('display');
    songLabelRecoverZindex();
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


document.getElementById('music-controls')
    .addEventListener('click', function (e) {
        // skip once
        if (shared.playbackQueueDisplay) {
            return;
        }
        // Exit if click came from any child element
        if (e.target !== this) {
            return;
        }
        if (!shared.lyricBodyActive) {
            shared.lyricBodyActive = true;
            lyricsBody.classList.add('display');
            document.getElementById("song-label").classList.add("reduceZindex");
        }
    });

document.getElementById('vice-music-controls')
    .addEventListener('click', function (e) {
        // skip once
        if (shared.playbackQueueDisplay) {
            return;
        }
        // Exit if click came from any child element
        if (e.target !== this) {
            return;
        }
        shared.lyricBodyActive = false;
        lyricsBody.classList.remove('display');
        songLabelRecoverZindex();
        clearTimeout(timeOut);
    });

function songLabelRecoverZindex() {
    setTimeout(() => {
        document.getElementById("song-label").classList.remove("songLabelRecoverZindex");
    }, 500);
}