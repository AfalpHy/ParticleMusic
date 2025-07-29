import { shared } from "./shared.js";

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
    const songs = document.getElementById('songs');
    const sorted = Array.from(songs.children).sort((a, b) => {
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