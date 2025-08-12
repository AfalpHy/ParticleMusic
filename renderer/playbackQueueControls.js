import { audioPlayer, lyricsPlayer, playbackQueue, shared, songList } from "./shared.js";

export function displayPlaybackQueue() {
    shared.playbackQueueDisplay = true;
    document.getElementById('playback-queue').classList.add('display');
}

export function hiddenPlaybackQueue() {
    shared.playbackQueueDisplay = false;
    document.getElementById('playback-queue').classList.remove('display');
}

export function updatePlaybackQueueDisplay() {
    document.getElementById('playback-queue-songs').textContent = "";
    const playbackQueueSongs = document.getElementById('playback-queue-songs');
    for (let i = 1; i < songList.children.length; i++) {
        const element = songList.children[i];
        const lineElement = document.createElement('div');
        lineElement.className = 'playback-queue-song-line';
        lineElement.filePath = element.filePath;
        {
            const columnElement = document.createElement('div');
            columnElement.className = 'playback-queue-song-line-main';

            const columnElementImg = document.createElement('img');
            columnElementImg.style.height = "50px";
            columnElementImg.style.width = "50px";
            columnElementImg.style.borderRadius = "10%";
            columnElementImg.src = element.children[1].children[0].src;

            const columnElementText1 = document.createElement('div');
            columnElementText1.className = 'playback-queue-song-line-title'
            columnElementText1.textContent = element.children[1].textContent;

            const columnElementText2 = document.createElement('div');
            columnElementText2.className = 'playback-queue-song-line-artist'
            columnElementText2.textContent = element.children[2].textContent;

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
            columnElementText.textContent = element.children[4].textContent;
            columnElement.append(columnElementText);
            lineElement.append(columnElement);
        }

        playbackQueueSongs.append(lineElement);
    }
}

export function playbackQueueEvent(element) {
    let className = element.className;
    let id = element.id;
    if (id == 'playback-queue-label') {
        return;
    }
    if (id == 'clear-playback-queue') {
        audioPlayer.pause();
        playbackQueue.clear();
        audioPlayer.currentTime = 0;
        document.querySelectorAll('.play-pause-btn').forEach(element => {
            element.style.backgroundImage = 'url(\'pictures/play.png\')';
        });
        document.getElementById('playback-queue-songs').textContent = "";
        lyricsPlayer.clear();
    } else {
        while (className != 'playback-queue-song-line') {
            element = element.parentNode;
            if (element) {
                className = element.className;
            } else {
                return;
            }
        }
        let index = 0;
        while ((element = element.previousElementSibling) != null) {
            index++;
        }
        playbackQueue.currentIndex = index;
        playbackQueue.load();
        playbackQueue.play = true;
        playbackQueue.playOrPause();
    }

}