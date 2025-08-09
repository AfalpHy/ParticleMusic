import { updatePlaybackQueueDisplay } from "./playbackQueueControls.js";
import { shared } from "./shared.js";
import { playbackQueue } from "./shared.js";

const resizer1 = document.getElementById('resizer1');
const resizer2 = document.getElementById('resizer2');
const songTtile = document.querySelector('.song-title');
const artist = document.querySelector('.artist');
const album = document.querySelector('.album');

let isDragging1 = false;
let isDragging2 = false;
let totalWidth;
resizer1.addEventListener('mousedown', (e) => {
    isDragging1 = true;
    totalWidth = songTtile.offsetWidth + artist.offsetWidth;
});

resizer2.addEventListener('mousedown', (e) => {
    isDragging2 = true;
    totalWidth = artist.offsetWidth + album.offsetWidth;
});

document.addEventListener('mousemove', (e) => {
    if (isDragging1) {
        const containerOffsetLeft = songTtile.getBoundingClientRect().left;
        const leftCurrentWidth = e.clientX - containerOffsetLeft;
        const containerWidth = songTtile.parentNode.offsetWidth;

        const leftPercent = (leftCurrentWidth / containerWidth) * 100;
        const rightPercent = (totalWidth - leftCurrentWidth) / containerWidth * 100;
        if (leftPercent < 10 || rightPercent < 10) {
            return;
        }

        document.querySelectorAll('.song-title')
            .forEach(element => element.style.flex = `0 0 ${leftPercent}%`)
        document.querySelectorAll('.artist').forEach(
            element => element.style.flex = `0 0 ${rightPercent}%`);
    }

    if (isDragging2) {
        const containerOffsetLeft = artist.getBoundingClientRect().left;
        const leftCurrentWidth = e.clientX - containerOffsetLeft;
        const containerWidth = artist.parentNode.offsetWidth;

        const leftPercent = (leftCurrentWidth / containerWidth) * 100;
        const rightPercent = (totalWidth - leftCurrentWidth) / containerWidth * 100;
        if (leftPercent < 10 || rightPercent < 10) {
            return;
        }

        document.querySelectorAll('.artist').forEach(
            element => element.style.flex = `0 0 ${leftPercent}%`)
        document.querySelectorAll('.album').forEach(
            element => element.style.flex = `0 0 ${rightPercent}%`);
    }
});

document.addEventListener('mouseup', () => {
    isDragging1 = false;
    isDragging2 = false;
});

function isAlphaNumeric(str) {
    return /^[A-Za-z0-9]+$/.test(str);
}

function compare(textA, textB) {
    if (isAlphaNumeric(textA[0])) {
        if (isAlphaNumeric(textB[0])) {
            return textA.localeCompare(textB);
        } else {
            return -1;
        }
    } else {
        if (isAlphaNumeric(textB[0])) {
            return 1;
        } else {
            return textA.localeCompare(textB, 'zh', { sensitivity: 'accent' });
        }
    }
}

function sortSongList(category, ascending) {
    const songs = document.getElementById('song-list');
    const sorted = Array.from(songs.children).slice(1).sort((a, b) => {
        const textA = a.children[category].textContent.trim()
        const textB = b.children[category].textContent.trim();
        if (ascending) {
            return compare(textA, textB);
        } else {
            return compare(textB, textA);
        }
    });
    let i = 1;
    let newPlaylist = [];
    sorted.forEach(element => {
        const index = element.children[0].textContent - 1;
        newPlaylist.push(shared.playlist[index]);
        element.children[0].textContent = i++;
        songs.appendChild(element);
    });
    shared.playlist = newPlaylist;
}

let songTtileAscending = false;
let artistAscending = false;
let albumAscending = false;
let durationAscending = false;
songTtile.addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    songTtileAscending = !songTtileAscending;
    sortSongList(1, songTtileAscending);
    // reset others
    artistAscending = false;
    albumAscending = false;
    durationAscending = false;
});

artist.addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    artistAscending = !artistAscending;
    sortSongList(2, artistAscending);
    songTtileAscending = false;
    albumAscending = false;
    durationAscending = false;
});


album.addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    albumAscending = !albumAscending;
    sortSongList(3, albumAscending);
    songTtileAscending = false;
    artistAscending = false;
    durationAscending = false;
});

document.querySelector('.duration').addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    durationAscending = !durationAscending;
    sortSongList(4, durationAscending);
    songTtileAscending = false;
    artistAscending = false;
    albumAscending = false;
});

export function addSongToList(message, coverDataUrl) {
    const songLabelChidren = document.getElementById('song-label').children;

    const lineElement = document.createElement('div');
    lineElement.className = 'song-line';

    for (let i = 0; i < message.length; i++) {
        const columnElement = document.createElement('div');
        columnElement.className = songLabelChidren[i].className;
        columnElement.style.overflow = 'hidden';

        if (i == 1) {
            const columnElementImg = document.createElement('img');
            columnElementImg.style.height = "40px";
            columnElementImg.style.width = "40px";
            columnElementImg.style.borderRadius = "10%";
            columnElementImg.src = coverDataUrl;
            columnElement.append(columnElementImg);
        }
        const columnElementText = document.createElement('div');
        columnElementText.className = 'song-line-column-text'
        columnElementText.textContent = message[i];
        columnElement.append(columnElementText);
        lineElement.append(columnElement);
    }

    document.getElementById('song-list').append(lineElement);

    lineElement.addEventListener('dblclick', () => {
        dblclickSong(parseInt(lineElement.children[0].textContent) - 1);
    });
}

function dblclickSong(index) {
    if (shared.loadingPlaylist) {
        return;
    }
    playbackQueue.empty = false;
    playbackQueue.metadatas = shared.playlist;
    playbackQueue.currentIndex = index;
    if (playbackQueue.playMode == 2) {
        playbackQueue.generateRandom();
    }
    playbackQueue.load();
    playbackQueue.play = true;
    playbackQueue.playOrPause();

    updatePlaybackQueueDisplay();
}