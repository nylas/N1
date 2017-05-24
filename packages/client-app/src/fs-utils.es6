import fs from 'fs'
import path from 'path';

function getSortedTimestampedFilesSync(filepath, basename, extension) {
  let files = fs.readdirSync(filepath);
  files = files.filter((file) => {
    const hasConfig = file.indexOf(`${basename}.`) > -1;
    const hasJSON = file.indexOf(`.${extension}`) > -1;
    const hasExactName = file.indexOf(`${basename}.${extension}`) > -1;
    return hasConfig && hasJSON && !hasExactName;
  });

  files = files.sort((a, b) => {
    const aValues = a.split('.');
    const bValues = b.split('.');

    return parseInt(aValues[1], 10) - parseInt(bValues[1], 10);
  });

  return files;
}

export function atomicWriteFileSync(filepath, basename, extension, content) {
  let fileNum = 0;
  let newFile;
  while (typeof newFile === "undefined" || fs.existsSync(newFile)) {
    const milliseconds = (new Date()).getTime() * 1000 + fileNum;
    newFile = path.join(filepath, `${basename}.${milliseconds}.${extension}`);
    fileNum++;
  }
  fs.writeFileSync(newFile, content);

  const files = getSortedTimestampedFilesSync(filepath, basename, extension);

  while (files.length > 10) {
    let fileToDelete = files.splice(0, 1);
    fileToDelete = fileToDelete[0];
    fs.unlinkSync(path.join(filepath, fileToDelete));
  }
}

export function getMostRecentTimestampedFile(filepath, basename, extension, offset = 0) {
  let myOffset = offset;
  if (myOffset < 0) myOffset = 0;
  if (myOffset > 9) myOffset = 9;

  const files = getSortedTimestampedFilesSync(filepath, basename, extension);

  return files[files.length - 1 - myOffset];
}
