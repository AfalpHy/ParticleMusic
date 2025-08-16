import { lyricPlaneCustomTitleBar, lyricsPlane, viceMusicControls } from './shared.js';
import { shared } from './shared.js';

const pullBtn = document.getElementById('pull');
const fullScreenBtn = document.getElementById('full-screen');
const windowControls = document.querySelectorAll('.window-controls')[1];

let timeout;
lyricsPlane.addEventListener('mousemove', () => {
    setControlsHiddenTimeout();
});

export function setControlsHiddenTimeout() {
    if (shared.lyricsPlaneActive) {
        clearTimeout(timeout);
        lyricPlaneCustomTitleBar.classList.remove('hidden');
        viceMusicControls.classList.remove('hidden');

        timeout = setTimeout(() => {
            lyricPlaneCustomTitleBar.classList.add('hidden');
            viceMusicControls.classList.add('hidden');
        }, 5000);
    }
}

export function pullLyricsPlane() {
    if (fullScreen) {
        return;
    }
    shared.lyricsPlaneActive = false;
    lyricsPlane.classList.remove('display');

    // prevent right-click events from accidentally triggering bottom drag-and-drop
    setTimeout(() => {
        lyricPlaneCustomTitleBar.style.visibility = 'hidden';
    }, 500)

    clearTimeout(timeout);
}

let fullScreen = false;
export function changeFullScreenMode() {
    fullScreen = !fullScreen;
    if (fullScreen) {
        pullBtn.style.visibility = 'hidden';
        fullScreenBtn.classList.add('change');
        windowControls.style.visibility = 'hidden';
        window.electronAPI.enterFullScreen();
    } else {
        pullBtn.style.visibility = 'visible';
        fullScreenBtn.classList.remove('change');
        windowControls.style.visibility = 'visible';
        window.electronAPI.leaveFullScreen();
    }
}

export function activeLyricsPlane() {
    if (!shared.lyricsPlaneActive) {
        shared.lyricsPlaneActive = true;
        lyricsPlane.classList.add('display');

        // prevent right-click events from accidentally triggering bottom drag-and-drop
        lyricPlaneCustomTitleBar.style.visibility = 'visible';

        setControlsHiddenTimeout();
    }
}
