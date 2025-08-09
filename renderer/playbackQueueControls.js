import { audioPlayer, lyricsPlayer, playbackQueue, shared } from "./shared.js";
import { formatTime } from "./shared.js";

let clickPlaybackQueueBtn = false;
let clickPlaybackQueue = false;
document.querySelectorAll('.playback-queue-btn')
    .forEach(element => element.addEventListener('click', () => {
        clickPlaybackQueueBtn = true;
        shared.playbackQueueDisplay = !shared.playbackQueueDisplay;
        if (shared.playbackQueueDisplay)
            document.getElementById('playback-queue').classList.add('display');
        else
            document.getElementById('playback-queue').classList.remove('display');
    }));

document.getElementById('playback-queue').addEventListener('click', () => {
    clickPlaybackQueue = true;
})

document.addEventListener('click', (e) => {
    if (clickPlaybackQueueBtn) {
        clickPlaybackQueueBtn = false;
        return;
    }
    if (clickPlaybackQueue) {
        clickPlaybackQueue = false;
        return;
    }

    if (shared.playbackQueueDisplay) {
        shared.playbackQueueDisplay = false;
        document.getElementById('playback-queue').classList.remove('display');
    }
})

export function updatePlaybackQueueDisplay() {
    document.getElementById('playback-queue-songs').innerHTML = "";
    const playbackQueueSongs = document.getElementById('playback-queue-songs');
    shared.playlist.forEach(element => {
        const lineElement = document.createElement('div');
        lineElement.className = 'playback-queue-song-line';
        {
            const columnElement = document.createElement('div');
            columnElement.className = 'playback-queue-song-line-main';

            const columnElementImg = document.createElement('img');
            columnElementImg.style.height = "50px";
            columnElementImg.style.width = "50px";
            columnElementImg.style.borderRadius = "10%";
            columnElementImg.src = element.coverDataUrl;

            const columnElementText1 = document.createElement('div');
            columnElementText1.className = 'playback-queue-song-line-title'
            columnElementText1.textContent = element.title;

            const columnElementText2 = document.createElement('div');
            columnElementText2.className = 'playback-queue-song-line-artist'
            columnElementText2.textContent = element.artist;

            columnElement.append(columnElementImg);
            columnElement.append(columnElementText1);
            columnElement.append(columnElementText2);

            lineElement.append(columnElement);
        }

        {
            const columnElement = document.createElement('div');
            columnElement.style.flex = '0 0 15%';
            columnElement.style.overflow = 'hidden';

            const columnElementText = document.createElement('div');
            columnElementText.className = 'song-line-column-text'
            columnElementText.textContent = formatTime(element.duration);
            columnElement.append(columnElementText);
            lineElement.append(columnElement);
        }

        playbackQueueSongs.append(lineElement);
        lineElement.addEventListener('click', () => {
            let tmp = lineElement;
            let index = 0;
            while ((tmp = tmp.previousElementSibling) != null) {
                index++;
            }
            playbackQueue.currentIndex = index;
            playbackQueue.load();
            playbackQueue.play = true;
            playbackQueue.playOrPause();
        });
    });
}

document.getElementById('clear-playback-queue').addEventListener('click', () => {
    audioPlayer.pause();
    playbackQueue.clear();
    audioPlayer.currentTime = 0;
    document.querySelectorAll('.play-pause-btn').forEach(element => {
        element.style.backgroundImage = 'url(\'pictures/play.png\')';
    });
    document.getElementById('playback-queue-songs').innerHTML = "";
    lyricsPlayer.clear();
})