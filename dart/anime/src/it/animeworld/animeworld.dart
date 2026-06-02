import 'dart:convert';

import 'package:mangayomi/bridge_lib.dart';

class AnimeWorld extends MProvider {
  AnimeWorld({required this.source});

  MSource source;

  final Client client = Client();

  String get baseUrl => source.baseUrl;

  @override
  Future<MPages> getPopular(int page) async {
    return parseTops('$baseUrl/tops/ongoing');
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    return parseAnimeList('$baseUrl/updated?page=$page');
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    final filters = filterList.filters;
    final keyword = Uri.encodeQueryComponent(cleanText(query));

    if (filters.isEmpty) {
      return parseAnimeList('$baseUrl/search?keyword=$keyword&page=$page');
    }

    String sort = '0';
    String url = '$baseUrl/filter?keyword=$keyword';

    for (var filter in filters) {
      if (filter.type == 'SortFilter') {
        sort = filter.values[filter.state].value;
      } else if (filter.type == 'TypeFilter') {
        for (var state in selectedStates(filter)) {
          url += '&type=${state.value}';
        }
      } else if (filter.type == 'GenreFilter') {
        for (var state in selectedStates(filter)) {
          url += '&genre=${state.value}';
        }
      } else if (filter.type == 'StatusFilter') {
        for (var state in selectedStates(filter)) {
          url += '&status=${state.value}';
        }
      } else if (filter.type == 'DubFilter') {
        for (var state in selectedStates(filter)) {
          url += '&dub=${state.value}';
        }
      } else if (filter.type == 'LanguageFilter') {
        for (var state in selectedStates(filter)) {
          url += '&language=${state.value}';
        }
      }
    }

    return parseAnimeList('$url&sort=$sort&page=$page');
  }

  @override
  Future<MManga> getDetail(String url) async {
    final res = (await client.get(Uri.parse(absoluteUrl(url)))).body;
    final document = parseHtml(res);
    final anime = MManga();

    anime.name = cleanText(
      document.selectFirst('div.widget.info h2.title')?.text ??
          document.selectFirst('#anime-title')?.text ??
          '',
    );
    anime.imageUrl = absoluteUrl(
      document.selectFirst('#thumbnail-watch img')?.attr('src') ??
          document.selectFirst('meta[name="og:image"]')?.attr('content') ??
          '',
    );
    anime.description = cleanText(
      document.selectFirst('div.widget.info div.desc')?.text ?? '',
    );
    anime.author = metaText(res, 'Studio');
    anime.status = parseStatus(metaText(res, 'Stato'), [
      {'In corso': 0, 'Finito': 1, 'Droppato': 3, 'Non rilasciato': 4},
    ]);
    anime.genre = xpath(
      res,
      '//dl[contains(@class,"meta")]/dt[contains(text(),"Genere")]/following-sibling::dd[1]//a/text()',
    ).map(cleanText).where((e) => e.isNotEmpty).toList();

    final episodesList = <MChapter>[];
    for (var element in document.select('div.server li.episode > a')) {
      final episode = MChapter();
      final number = cleanText(
        element.attr('data-episode-num') ??
            element.attr('data-num') ??
            element.text,
      );
      episode.name = number.isEmpty ? cleanText(element.text) : 'Ep. $number';
      episode.url = absoluteUrl(element.attr('href'));
      episodesList.add(episode);
    }
    anime.chapters = episodesList.reversed.toList();

    return anime;
  }

  @override
  Future<List<MVideo>> getVideoList(String url) async {
    final episodeUrl = absoluteUrl(url);
    final res = (await client.get(Uri.parse(episodeUrl))).body;
    final document = parseHtml(res);
    final token =
        document.selectFirst('#player')?.attr('data-id') ??
        Uri.parse(episodeUrl).pathSegments.last;

    var videos = await getAnimeWorldVideos(token, episodeUrl, '0');
    if (videos.isEmpty) {
      videos = await getAnimeWorldVideos(token, episodeUrl, '1');
    }
    return videos;
  }

  Future<MPages> parseAnimeList(String url) async {
    final res = (await client.get(Uri.parse(url))).body;
    final document = parseHtml(res);
    final animeList = <MManga>[];

    for (var element in document.select('div.film-list div.item')) {
      final anime = MManga();
      var name = cleanText(element.selectFirst('a.name')?.text ?? '');

      anime.name = name;
      anime.imageUrl = absoluteUrl(
        element.selectFirst('img')?.attr('src') ?? '',
      );
      anime.link =
          element.selectFirst('a.poster')?.attr('href') ??
          element.selectFirst('a')?.attr('href') ??
          '';

      if (anime.name.isNotEmpty && anime.link.isNotEmpty) {
        animeList.add(anime);
      }
    }

    final currentPage =
        int.tryParse(Uri.parse(url).queryParameters['page'] ?? '1') ?? 1;
    final totalPage =
        int.tryParse(
          cleanText(document.selectFirst('span.total')?.text ?? ''),
        ) ??
        currentPage;
    return MPages(animeList, currentPage < totalPage);
  }

  Future<MPages> parseTops(String url) async {
    final res = (await client.get(Uri.parse(url))).body;
    final document = parseHtml(res);
    final animeList = <MManga>[];

    for (var element in document.select('div.item.w-100')) {
      final anime = MManga();
      var name = cleanText(element.selectFirst('div.name.mb-2')?.text ?? '');
      anime.name = name;
      anime.imageUrl = absoluteUrl(
        element.selectFirst('img.tops-thumbnail')?.attr('src') ?? '',
      );
      anime.link = element.selectFirst('a')?.attr('href') ?? '';
      if (anime.name.isNotEmpty && anime.link.isNotEmpty) {
        animeList.add(anime);
      }
    }
    return MPages(animeList, false);
  }

  Future<List<MVideo>> getAnimeWorldVideos(
    String token,
    String episodeUrl,
    String alt,
  ) async {
    try {
      final infoUrl =
          '$baseUrl/api/episode/info?id=${Uri.encodeQueryComponent(token)}&alt=$alt';
      final infoRes = (await client.get(Uri.parse(infoUrl))).body;
      final info = json.decode(infoRes) as Map<String, dynamic>;

      String videoUrl = '${info['grabber'] ?? ''}';
      final target = '${info['target'] ?? ''}';
      if (videoUrl.isEmpty && target.isNotEmpty) {
        final playerRes = (await client.get(
          Uri.parse(absoluteUrl(target)),
        )).body;
        videoUrl =
            parseHtml(playerRes).selectFirst('source')?.attr('src') ?? '';
      }

      if (videoUrl.isEmpty) {
        return [];
      }

      final video = MVideo();
      video
        ..url = videoUrl
        ..originalUrl = videoUrl
        ..quality = alt == '1' ? 'AnimeWorld Alternativo' : 'AnimeWorld'
        ..headers = {'Referer': episodeUrl};
      return [video];
    } catch (_) {
      return [];
    }
  }

  List selectedStates(dynamic filter) {
    return (filter.state as List).where((e) => e.state == true).toList();
  }

  String metaText(String res, String label) {
    return cleanText(
      xpath(
        res,
        '//dl[contains(@class,"meta")]/dt[contains(text(),"$label")]/following-sibling::dd[1]//text()',
      ).join(' '),
    );
  }

  String absoluteUrl(String url) {
    if (url.isEmpty) {
      return url;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }

  String cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter('TypeFilter', 'Tipo', [
        CheckBoxFilter('Anime', '0'),
        CheckBoxFilter('Movie', '4'),
        CheckBoxFilter('OVA', '1'),
        CheckBoxFilter('ONA', '2'),
        CheckBoxFilter('Special', '3'),
        CheckBoxFilter('Music', '5'),
      ]),
      GroupFilter('GenreFilter', 'Generi', [
        CheckBoxFilter('Arti Marziali', '3'),
        CheckBoxFilter('Avanguardia', '5'),
        CheckBoxFilter('Avventura', '2'),
        CheckBoxFilter('Azione', '1'),
        CheckBoxFilter('Bambini', '47'),
        CheckBoxFilter('Commedia', '4'),
        CheckBoxFilter('Demoni', '6'),
        CheckBoxFilter('Drammatico', '7'),
        CheckBoxFilter('Ecchi', '8'),
        CheckBoxFilter('Fantasy', '9'),
        CheckBoxFilter('Gioco', '10'),
        CheckBoxFilter('Harem', '11'),
        CheckBoxFilter('Hentai', '43'),
        CheckBoxFilter('Horror', '13'),
        CheckBoxFilter('Josei', '14'),
        CheckBoxFilter('Magia', '16'),
        CheckBoxFilter('Mecha', '18'),
        CheckBoxFilter('Militari', '19'),
        CheckBoxFilter('Mistero', '21'),
        CheckBoxFilter('Musicale', '20'),
        CheckBoxFilter('Parodia', '22'),
        CheckBoxFilter('Polizia', '23'),
        CheckBoxFilter('Psicologico', '24'),
        CheckBoxFilter('Romantico', '46'),
        CheckBoxFilter('Samurai', '26'),
        CheckBoxFilter('Sci-Fi', '28'),
        CheckBoxFilter('Scolastico', '27'),
        CheckBoxFilter('Seinen', '29'),
        CheckBoxFilter('Sentimentale', '25'),
        CheckBoxFilter('Shoujo', '30'),
        CheckBoxFilter('Shoujo Ai', '31'),
        CheckBoxFilter('Shounen', '32'),
        CheckBoxFilter('Shounen Ai', '33'),
        CheckBoxFilter('Slice of Life', '34'),
        CheckBoxFilter('Spazio', '35'),
        CheckBoxFilter('Soprannaturale', '37'),
        CheckBoxFilter('Sport', '36'),
        CheckBoxFilter('Storico', '12'),
        CheckBoxFilter('Superpoteri', '38'),
        CheckBoxFilter('Thriller', '39'),
        CheckBoxFilter('Vampiri', '40'),
        CheckBoxFilter('Veicoli', '48'),
        CheckBoxFilter('Yaoi', '41'),
        CheckBoxFilter('Yuri', '42'),
      ]),
      GroupFilter('StatusFilter', 'Stato', [
        CheckBoxFilter('In corso', '0'),
        CheckBoxFilter('Finito', '1'),
        CheckBoxFilter('Non rilasciato', '2'),
        CheckBoxFilter('Droppato', '3'),
      ]),
      GroupFilter('DubFilter', 'Sottotitoli', [
        CheckBoxFilter('Subbato', '0'),
        CheckBoxFilter('Doppiato', '1'),
      ]),
      GroupFilter('LanguageFilter', 'Audio', [
        CheckBoxFilter('Giapponese', 'jp'),
        CheckBoxFilter('Italiano', 'it'),
        CheckBoxFilter('Cinese', 'ch'),
        CheckBoxFilter('Coreano', 'kr'),
        CheckBoxFilter('Inglese', 'en'),
      ]),
      SelectFilter('SortFilter', 'Ordine', 0, [
        SelectFilterOption('Standard', '0'),
        SelectFilterOption('Ultime aggiunte', '1'),
        SelectFilterOption('Lista A-Z', '2'),
        SelectFilterOption('Lista Z-A', '3'),
        SelectFilterOption('Piu vecchi', '4'),
        SelectFilterOption('Piu recenti', '5'),
        SelectFilterOption('Piu visti', '6'),
      ]),
    ];
  }
}

AnimeWorld main(MSource source) {
  return AnimeWorld(source: source);
}
