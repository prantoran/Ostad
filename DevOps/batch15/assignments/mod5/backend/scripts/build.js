// "Build" step for the backend: copy runtime files into dist/ and stamp the version.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const dist = path.join(root, 'dist');
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });

fs.cpSync(path.join(root, 'src'), path.join(dist, 'src'), { recursive: true });
fs.copyFileSync(path.join(root, 'package.json'), path.join(dist, 'package.json'));
if (fs.existsSync(path.join(root, 'package-lock.json'))) {
  fs.copyFileSync(path.join(root, 'package-lock.json'), path.join(dist, 'package-lock.json'));
}
fs.writeFileSync(path.join(dist, 'VERSION'), `${process.env.GIT_SHA || 'dev'}\n`);
console.log('backend build complete ->', dist);
