from pathlib import Path
root = Path(__file__).resolve().parents[1]
folder = root / '预览' / '餐厅学校医院_3D_v22'
path = folder / '装饰与场景改造预览.html'
text = path.read_text(encoding='utf-8')
start = min(i for i in (text.find('<h2>游戏实景</h2>'), text.find('<h2>房间嵌合实景</h2>'), text.find('<h2>庭院与小街</h2>')) if i >= 0)
end = text.index('<h2>50 件素材近景</h2>')
scenes = [('apt_1','公寓一层 · 房间直接相连'),('apt_2','公寓二层 · 不同大小的卧室与工作间'),
          ('community_1','社区馆 · 活动厅、书店与咖啡房'),('restaurant_1','餐厅 · 用餐、吧台与厨房嵌合'),
          ('school_1','学校 · 教室、备课与科学学习'),('hospital_1','医院 · 门诊与候诊分区'),
          ('music_2','音乐馆二层 · 琴房与排练室')]
outdoor = [('garden','重做 · 青柠花房：折角温室、花岛和树下茶庭'),
           ('market','重做 · 海风集市：错位店铺与扇形海岸平台'),
           ('reading_court','新增 · 漂流书庭：书亭、手作平台与阅读花庭'),
           ('civic_garden','新增 · 蓝湾公共花园：活动舞台与花径')]
outdoor_cards = []
for scene, label in outdoor:
    image = scene + '_庭院重做.png'
    assert (folder / image).exists(), image
    outdoor_cards.append(f'<figure><a href="{image}"><img loading="lazy" src="{image}" alt="{label}"></a><figcaption>{label}</figcaption></figure>')
cards = []
for scene, label in scenes:
    image = scene + '_房间嵌合整层.png'
    assert (folder / image).exists(), image
    cards.append(f'<figure><a href="{image}"><img loading="lazy" src="{image}" alt="{label}"></a><figcaption>{label}</figcaption></figure>')
section = '<h2>庭院与小街</h2><p>两张旧地图重做，两张新庭院可从街区门架进入。异形地面、弧形花岛、折线步道、开敞书亭与轻巧棚架，沿用游戏原有蓝灰、奶白与浅木色。</p><div class="grid">' + ''.join(outdoor_cards) + '</div><h2>房间嵌合实景</h2><p>19 个楼层使用错位双排、侧厅嵌合、梯级叠房、中央套间四种布局。大小房间紧靠、共用隔墙，从房间直接进入相邻房间。</p><div class="grid">' + ''.join(cards) + '</div>'
text = text[:start] + section + text[end:]
text = text.replace('50 件家具与装饰。曲面、软垫、开放层架和细支架，让不同房间有清楚的用途与轮廓。点击图片查看原尺寸。',
                    'v22 的 19 个楼层已有四种房间嵌合布局；温室、集市重做，新增阅读庭与公共花园。点击图片查看游戏实景原图。')
text = text.replace('v22 的 19 个楼层已改为房间嵌合布局，同时保留 50 件家具与装饰。点击图片查看原尺寸。', 'v22 的 19 个楼层已有四种房间嵌合布局；温室、集市重做，新增阅读庭与公共花园。点击图片查看游戏实景原图。')
path.write_text(text, encoding='utf-8')
print('Current gallery: four outdoor scenes, seven floors, fifty existing detailed props')
