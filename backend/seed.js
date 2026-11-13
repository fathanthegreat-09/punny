const fs = require('fs');
const path = require('path');

const titles = [
  'Shirasu Azusa', 'Igusa Haruka', 'Yutori Natsu', 'Kyoukama Kazusa', 'Mob-chan~',
  'Serina and Hanae', 'Cheerleader kei', 'cheerleader arona and plana', 'Tyrant', 'Hanae',
  'Laffey', 'Miyu Maid', 'Miyu', 'cheerleader kokona', 'cheerleader yuuka',
  'cheerleader noa', 'shirao eri', 'eri eri', 'hasumi', 'nanagami rin',
  'tyrant stella sora', 'akane', 'miyu', 'sorasaki hina', 'aris maid',
  'aris battle suit', 'kei swimsuit', 'misuzu', 'tsubasa', 'eri',
  'eri', 'aru', 'rio maid', 'rio dress', 'rio dress',
  'shiroko terror casual', 'asuna', 'rio', 'chinatsu', 'mika',
  'mine idol', 'rio', 'rio', 'aru', 'chitose'
];

const posts = titles.map((title, idx) => {
  const num = idx === 0 ? '' : (idx + 1);
  return {
    id: `pin-${idx + 1}`,
    title: title,
    imageUrl: `assets/images/file${num}.jpg`,
    author: (idx % 3 === 0) ? 'Fathan' : ((idx % 2 === 0) ? 'Sensei' : 'Arona'),
    likes: (idx % 4 === 0) ? ['Fathan'] : [],
    likeCount: (idx % 4 === 0) ? 1 : 0,
    createdAt: new Date(Date.now() - (45 - idx) * 60000).toISOString()
  };
});

const dataDir = path.join(__dirname, 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

fs.writeFileSync(path.join(dataDir, 'posts.json'), JSON.stringify(posts, null, 2), 'utf-8');
console.log(`Successfully generated ${posts.length} posts in posts.json!`);
