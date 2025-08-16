import { audioPlayer, lyricsPlayer, playQueue, playQueueSongs, playQueueSongMenu, shared, songList } from "./shared.js";

export function changePlayQueueDisplayStatus() {
    shared.playQueueDisplay = !shared.playQueueDisplay;
    if (shared.playQueueDisplay) {
        document.getElementById('play-queue').classList.add('display');
    } else {
        document.getElementById('play-queue').classList.remove('display');
    }
}

export function updatePlayQueue() {
    playQueueSongs.textContent = "";
    for (let i = 1; i < songList.children.length; i++) {
        addSongToPlayQueue(i);
    }
}

export function addSongToPlayQueue(index) {
    const element = songList.children[index];
    const lineElement = document.createElement('div');
    lineElement.className = 'play-queue-song-line';
    lineElement.filePath = element.filePath;
    {
        const columnElement = document.createElement('div');
        columnElement.className = 'play-queue-song-line-main';

        const columnElementImg = document.createElement('img');
        columnElementImg.style.height = "50px";
        columnElementImg.style.width = "50px";
        columnElementImg.style.borderRadius = "10%";
        columnElementImg.src = element.children[1].children[0].src;

        const columnElementText1 = document.createElement('div');
        columnElementText1.className = 'play-queue-song-line-title'
        columnElementText1.textContent = element.children[1].textContent;

        const columnElementText2 = document.createElement('div');
        columnElementText2.className = 'play-queue-song-line-artist'
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
    if (playQueue.playMode == 2) {
        lineElement.index = playQueue.songLines.length;
        playQueue.songLines.push({ element: lineElement, valid: true });
        console.log(playQueue.songLines[lineElement.index].element.filePath);
    }

    playQueueSongs.append(lineElement);
    playQueue.empty = false;
}

export function playQueueEvent(element) {
    let className = element.className;
    let id = element.id;
    if (id == 'play-queue-label') {
        return;
    }
    if (id == 'clear-play-queue') {
        playQueue.clear();
    } else {
        while (className != 'play-queue-song-line') {
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
        playQueue.currentIndex = index;
        playQueue.load();
        playQueue.play = true;
        playQueue.playOrPause();
    }
}

export function playQueueSongMemuEvent(element) {
    const content = element.textContent;
    playQueueSongMenu.style.visibility = 'hidden';
    if (content == 'remove') {
        playQueue.remove(shared.clickPlayQueueSongIndex);
    } else if (content == 'play next') {
        playQueue.insert2Next(shared.clickPlayQueueSongIndex);
    } else {
        // if click blank area
        playQueueSongMenu.style.visibility = 'visible';
    }
}