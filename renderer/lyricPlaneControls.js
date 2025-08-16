import { changePlayQueueDisplayStatus } from './playQueueControls.js';
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

    // prevent right-click events from accidentally triggering bottom drag-and-drop
    setTimeout(() => {
        customTitleBar.style.visibility = 'hidden';
    }, 500)

    clearTimeout(timeout);
    if (shared.playQueueDisplay) {
        changePlayQueueDisplayStatus();
    }
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
    if (shared.playQueueDisplay) {
        changePlayQueueDisplayStatus();
    }
}

export function activeLyricsPlane() {
    if (!shared.lyricsPlaneActive) {
        shared.lyricsPlaneActive = true;
        lyricsPlane.classList.add('display');

        // prevent right-click events from accidentally triggering bottom drag-and-drop
        customTitleBar.style.visibility = 'visible';

        setControlsHiddenTimeout();
        if (shared.playQueueDisplay) {
            changePlayQueueDisplayStatus();
        }
    }
}
