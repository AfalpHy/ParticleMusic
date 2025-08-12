import { updatePlaybackQueueDisplay } from "./playbackQueueControls.js";
import { shared, songList } from "./shared.js";
import { playbackQueue } from "./shared.js";

const search = document.getElementById('search');
const searchList = songList.cloneNode(false);

searchList.appendChild(songList.children[0].cloneNode(true));
songList.parentNode.append(searchList);

search.addEventListener('input', (event) => {
    for (let i = searchList.children.length - 1; i > 0; i--) {
        searchList.removeChild(searchList.children[i]);
    }
    document.getElementById('cover').style.display = 'none';
    if (event.target.value == "") {
        songList.style.display = "block";
        searchList.style.display = "none";
        return;
    }
    let index = 1;
    for (let i = 1; i < songList.children.length; i++) {
        const line = songList.children[i];
        for (let j = 1; j <= 3; j++) {
            if (line.children[j].textContent.includes(event.target.value)) {
                const lineClone = line.cloneNode(true);
                lineClone.addEventListener('dblclick', () => {
                    dblclickSong(parseInt(line.children[0].textContent) - 1);
                });
                lineClone.children[0].textContent = index++;
                searchList.appendChild(lineClone);
                break;
            }
        }
    }
    songList.style.display = "none";
    searchList.style.display = "block";

    // repaint immediately to avoid shadows
    songList.style.transform = 'translateZ(0)';
});

let songTtile;
let artist;
let album;

let isDragging1 = false;
let isDragging2 = false;
let totalWidth;

export function enableResizer1() {
    isDragging1 = true;
    if (songList.style.display == 'block') {
        songTtile = songList.children[0].children[1];
        artist = songList.children[0].children[2];
    } else {
        songTtile = searchList.children[0].children[1];
        artist = searchList.children[0].children[2];
    }
    totalWidth = songTtile.offsetWidth + artist.offsetWidth;
}

export function enableResizer2() {
    isDragging2 = true;
    if (songList.style.display == 'block') {
        artist = songList.children[0].children[2];
        album = songList.children[0].children[3];
    } else {
        artist = searchList.children[0].children[2];
        album = searchList.children[0].children[3];
    }
    totalWidth = artist.offsetWidth + album.offsetWidth;
}

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

let playlistOrderChanged = false;
function sortSongList(category, ascending) {
    const sorted = Array.from(songList.children).slice(1).sort((a, b) => {
        const textA = a.children[category].textContent.trim()
        const textB = b.children[category].textContent.trim();
        if (ascending) {
            return compare(textA, textB);
        } else {
            return compare(textB, textA);
        }
    });
    let i = 1;
    sorted.forEach(element => {
        element.children[0].textContent = i++;
        songList.appendChild(element);
    });
    playlistOrderChanged = true;
}

let songTtileAscending = false;
let artistAscending = false;
let albumAscending = false;
let durationAscending = false;

export function sortSongByTitle() {
    if (shared.loadingPlaylist || songList.style.display == 'none') {
        return;
    }
    songTtileAscending = !songTtileAscending;
    sortSongList(1, songTtileAscending);
    // reset others
    artistAscending = false;
    albumAscending = false;
    durationAscending = false;
}

export function sortSongByArtist() {
    if (shared.loadingPlaylist || songList.style.display == 'none') {
        return;
    }
    artistAscending = !artistAscending;
    sortSongList(2, artistAscending);
    songTtileAscending = false;
    albumAscending = false;
    durationAscending = false;
}

export function sortSongByAlbum() {
    if (shared.loadingPlaylist || songList.style.display == 'none') {
        return;
    }
    albumAscending = !albumAscending;
    sortSongList(3, albumAscending);
    songTtileAscending = false;
    artistAscending = false;
    durationAscending = false;
}

export function sortSongByDuration() {
    if (shared.loadingPlaylist || songList.style.display == 'none') {
        return;
    }
    durationAscending = !durationAscending;
    sortSongList(4, durationAscending);
    songTtileAscending = false;
    artistAscending = false;
    albumAscending = false;
}

export function addSongToList(message, coverDataUrl, filePath) {
    const songLabelChidren = document.getElementById('song-label').children;

    const lineElement = document.createElement('div');
    lineElement.className = 'song-line';

    for (let i = 0; i < message.length; i++) {
        const columnElement = document.createElement('div');
        columnElement.className = songLabelChidren[i].className;
        columnElement.style.flex = songLabelChidren[i].style.flex;
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

    songList.append(lineElement);
    lineElement.filePath = filePath;
    lineElement.addEventListener('dblclick', () => {
        dblclickSong(parseInt(lineElement.children[0].textContent) - 1);
    });
    playlistOrderChanged = true;
}

function dblclickSong(index) {
    if (shared.loadingPlaylist) {
        return;
    }
    playbackQueue.currentIndex = index;
    if (playbackQueue.empty || playlistOrderChanged || playbackQueue.playMode == 2) {
        playbackQueue.empty = false;
        playlistOrderChanged = false;
        updatePlaybackQueueDisplay();
    }
    playbackQueue.load();
    playbackQueue.play = true;
    playbackQueue.playOrPause();
    if (playbackQueue.playMode == 2) {
        playbackQueue.shuffle();
    }
}