import { audioPlayer } from "./shared.js";
import { lyricsPlayer } from "./shared.js";
import { playQueue } from "./shared.js";
import { formatTime } from "./shared.js";

audioPlayer.volume = 0.3;

let isDraggingProcessBar = false;
const progressBarElements = document.querySelectorAll('.progress');

function mmssToSeconds(timeStr) {
    const [minutes, seconds] = timeStr.split(':').map(Number);
    return minutes * 60 + seconds;
}

function updateProgressDisplay() {
    const currentTime = audioPlayer.currentTime;
    const duration = mmssToSeconds(playQueue.currentSong.children[1].textContent);
    const currentTimeElements = document.querySelectorAll('.current-time');
    const totalTimeElements = document.querySelectorAll('.total-time');
    currentTimeElements.forEach(element => {
        element.textContent = `${formatTime(currentTime)}`;
    });

    totalTimeElements.forEach(element => {
        element.textContent = `${formatTime(duration)}`;
    });

    const progress = (currentTime / duration) * 100;
    if (!isDraggingProcessBar) {
        progressBarElements.forEach(element => {
            element.style.background = `linear-gradient(to right, black 0%, black ${progress}%, #d3d3d3 ${progress}%, #d3d3d3 100%)`;
            element.value = progress;
        })
    }

    lyricsPlayer.update();
}

progressBarElements.forEach(element => {
    element.addEventListener('mouseenter', () => {
        if (!playQueue.empty) element.classList.add('hover');
    });
})

progressBarElements.forEach(element => {
    element.addEventListener('mouseleave', () => {
        if (!playQueue.empty) element.classList.remove('hover');
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
        if (!playQueue.empty) {
            const seekTime =
                (element.value / 100) * mmssToSeconds(playQueue.currentSong.children[1].textContent);
            audioPlayer.currentTime = seekTime;
        }
    });
})

progressBarElements.forEach(element => {
    element.addEventListener('input', () => {
        const progress = element.value;
        element.style.background = `linear-gradient(to right, black 0%, black ${progress}%, #d3d3d3 ${progress}%, #d3d3d3 100%)`;
    });
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
                `linear-gradient(to right, black 0%, black ${element.value}%, #d3d3d3 ${element.value}%, #d3d3d3 100%)`
        });
}

let tempVolume = volumeSlider[0].value;
volumeSlider.forEach(element => element.addEventListener('input', () => {
    tempVolume = element.value;
    adjustVolume(element.value / 100);
}));

export function switchMute() {
    if (volumeSlider[0].value != 0) {
        adjustVolume(0);
    } else {
        adjustVolume(tempVolume / 100);
    }
}

audioPlayer.addEventListener('timeupdate', updateProgressDisplay);

audioPlayer.addEventListener('ended', () => {
    // repeat
    if (playQueue.playMode == 1) {
        playQueue.load();
        playQueue.playOrPause();
        return;
    }
    playQueue.next();
})
