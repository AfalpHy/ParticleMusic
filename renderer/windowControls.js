
document.querySelectorAll('.minimize')
    .forEach(
        element => {
            element.addEventListener(
                'click', () => { window.electronAPI.minimizeWindow() })
        });

document.querySelectorAll('.maximize')
    .forEach(
        element => {
            element.addEventListener(
                'click', () => { window.electronAPI.resizeWindow() })
        });

window.electronAPI.maximize(() => {
    document.querySelectorAll('.maximize').forEach(element => {
        element.style.backgroundImage = 'url(\'pictures/unmaximize.png\')';
    });
})

window.electronAPI.unmaximize(() => {
    document.querySelectorAll('.maximize').forEach(element => {
        element.style.backgroundImage = 'url(\'pictures/maximize.png\')';
    });
})

document.querySelectorAll('.close').forEach(
    element => {
        element.addEventListener(
            'click', () => { window.electronAPI.closeWindow() })
    });