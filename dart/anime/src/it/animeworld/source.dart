import '../../../../../model/source.dart';

Source get animeworld => _animeworld;
const _animeworldVersion = '0.0.14';
const _animeworldCodeUrl =
    'https://raw.githubusercontent.com/christianscano/mangayomi-extensions/$branchName/dart/anime/src/it/animeworld/animeworld.dart';

Source _animeworld = Source(
  id: 368490446,
  name: 'AnimeWorld',
  baseUrl: 'https://www.animeworld.ac',
  lang: 'it',
  typeSource: 'single',
  iconUrl:
      'https://raw.githubusercontent.com/christianscano/mangayomi-extensions/$branchName/dart/anime/src/it/animeworld/icon.png',
  sourceCodeUrl: _animeworldCodeUrl,
  version: _animeworldVersion,
  itemType: ItemType.anime,
);
