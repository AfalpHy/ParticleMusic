import { player, playQueue, playQueuePlane, playQueueSongMenu, shared, songList } from "./shared.js";
import { searchSongList } from "./songList.js";

export function displayPlayQueuePlane() {
    shared.playQueueDisplay = true;
    playQueuePlane.classList.add('display');
}

export function hiddenPlayQueuePlane() {
    shared.playQueueDisplay = false;
    playQueuePlane.classList.remove('display');
}

export function updatePlayQueue(isSongList) {
    playQueue.textContent = "";
    if (isSongList) {
        for (let i = 1; i < songList.children.length; i++) {
            addSongToPlayQueue(i);
        }
    } else {
        for (let i = 1; i < searchSongList.children.length; i++) {
            addSongToPlayQueue(searchSongList.children[i].originIndex);
        }
    }
}

export function addSongToPlayQueue(index) {
    const element = songList.children[index];
    const lineElement = document.createElement('div');
    lineElement.className = 'play-queue-line';
    lineElement.filePath = element.filePath;
    {
        const columnElement = document.createElement('div');
        columnElement.className = 'play-queue-line-main';

        const columnElementImg = document.createElement('img');
        columnElementImg.style.height = "50px";
        columnElementImg.style.width = "50px";
        columnElementImg.style.borderRadius = "10%";
        columnElementImg.src = element.children[1].children[0].src;

        const columnElementText1 = document.createElement('div');
        columnElementText1.className = 'play-queue-line-title'
        columnElementText1.textContent = element.children[1].textContent;

        const columnElementText2 = document.createElement('div');
        columnElementText2.className = 'play-queue-line-artist'
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
    if (player.playMode == 2) {
        lineElement.index = player.songLines.length;
        player.songLines.push({ element: lineElement, valid: true });
    }

    playQueue.append(lineElement);
    player.empty = false;
}

export function playQueueEvent(element) {
    let className = element.className;
    let id = element.id;
    if (id == 'play-queue-label') {
        return;
    }
    if (id == 'clear-play-queue') {
        player.clear();
    } else {
        while (className != 'play-queue-line') {
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
        player.currentIndex = index;
        player.load();
        player.play = true;
        player.playOrPause();
    }
}

export function playQueueSongMemuEvent(element) {
    const content = element.textContent;
    playQueueSongMenu.style.visibility = 'hidden';
    if (content == 'remove') {
        player.remove(shared.clickPlayQueueSongIndex);
    } else if (content == 'play next') {
        player.insert2Next(shared.clickPlayQueueSongIndex);
    } else {
        // if click blank area
        playQueueSongMenu.style.visibility = 'visible';
    }
}