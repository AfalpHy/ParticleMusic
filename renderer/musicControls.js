import { audioPlayer } from "./shared.js";
import { lyricsPlayer } from "./shared.js";
import { playbackQueue } from "./shared.js";
import { formatTime } from "./shared.js";

audioPlayer.volume = 0.3;

document.querySelectorAll('.last-btn')
    .forEach(element => {
        element.addEventListener('click', () => {
            if (!playbackQueue.empty) {
                playbackQueue.last();
            }
        })
    });

document.querySelectorAll('.play-pause-btn')
    .forEach(element => {
        element.addEventListener('click', () => {
            if (!playbackQueue.empty) {
                playbackQueue.play = !playbackQueue.play;
                playbackQueue.playOrPause();
            }
        })
    });

document.querySelectorAll('.next-btn')
    .forEach(element => {
        element.addEventListener('click', () => {
            if (!playbackQueue.empty) {
                playbackQueue.next();
            }
        })
    });

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

document.querySelectorAll('.volume-icon')
    .forEach(element => {
        element.addEventListener('click', () => {
            if (volumeSlider[0].value != 0) {
                adjustVolume(0);
            } else {
                adjustVolume(tempVolume / 100);
            }
        })
    });

audioPlayer.addEventListener('timeupdate', updateProgressDisplay);

audioPlayer.addEventListener('ended', () => {
    playbackQueue.next();
})
