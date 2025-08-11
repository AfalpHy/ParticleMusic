import { lyricsBody } from './shared.js';
import { shared } from './shared.js';

const pullBtn = document.getElementById('pull');
const fullScreenBtn = document.getElementById('full-screen');
const windowControls = document.querySelectorAll('.window-controls')[1];
const customTitleBar = document.querySelectorAll('.custom-title-bar')[1];
const viceMusicControls = document.getElementById('vice-music-controls');

let timeOut;
lyricsBody.addEventListener('mousemove', () => {
    if (shared.lyricsBodyActive) {
        clearTimeout(timeOut);
        customTitleBar.classList.remove('hidden');
        viceMusicControls.classList.remove('hidden');

        timeOut = setTimeout(() => {
            customTitleBar.classList.add('hidden');
            viceMusicControls.classList.add('hidden');
        }, 5000);
    }
});

export function pullLyricsBody() {
    if (fullScreen) {
        return;
    }
    shared.lyricsBodyActive = false;
    lyricsBody.classList.remove('display');
    clearTimeout(timeOut);
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

export function activeLyricsBody() {
    if (!shared.lyricsBodyActive) {
        shared.lyricsBodyActive = true;
        lyricsBody.classList.add('display');
    }
}
