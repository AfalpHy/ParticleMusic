import { lyricsPlane } from './shared.js';
import { shared } from './shared.js';

const pullBtn = document.getElementById('pull');
const fullScreenBtn = document.getElementById('full-screen');
const windowControls = document.querySelectorAll('.window-controls')[1];
const customTitleBar = document.querySelectorAll('.custom-title-bar')[1];
const viceMusicControls = document.getElementById('vice-music-controls');

let timeout;
lyricsPlane.addEventListener('mousemove', () => {
    setControlsHiddenTimeout();
});

export function setControlsHiddenTimeout() {
    if (shared.lyricsPlaneActive) {
        clearTimeout(timeout);
        customTitleBar.classList.remove('hidden');
        viceMusicControls.classList.remove('hidden');

        timeout = setTimeout(() => {
            customTitleBar.classList.add('hidden');
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
        setControlsHiddenTimeout();
    }
}
