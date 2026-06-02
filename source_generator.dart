import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart/anime/anime_source_list.dart';
import 'dart/manga/manga_source_list.dart';
import 'dart/novel/novel_source_list.dart';
import 'model/source.dart';

void main() {
  final jsSources = _searchJsSources(Directory("javascript"));
  genManga(
    jsSources.where((element) => element.itemType!.name == "manga").toList(),
  );
  genAnime(
    jsSources.where((element) => element.itemType!.name == "anime").toList(),
  );
  genNovel(
    jsSources.where((element) => element.itemType!.name == "novel").toList(),
  );
}

void genManga(List<Source> jsMangasourceList) {
  List<Source> mangaSources = [];
  mangaSources.addAll(dartMangasourceList);
  mangaSources.addAll(jsMangasourceList);
  final List<Map<String, dynamic>> jsonList = mangaSources
      .map((source) => source.toJson())
      .toList();
  final jsonString = jsonEncode(jsonList);

  final file = File('index.json');
  file.writeAsStringSync(jsonString);

  log('JSON file created: ${file.path}');
}

void genAnime(List<Source> jsAnimesourceList) {
  List<Source> animeSources = [];
  animeSources.addAll(dartAnimesourceList);
  animeSources.addAll(jsAnimesourceList);
  final List<Map<String, dynamic>> jsonList = animeSources
      .map((source) => source.toJson())
      .toList();
  final jsonString = jsonEncode(jsonList);

  final file = File('anime_index.json');
  file.writeAsStringSync(jsonString);

  log('JSON file created: ${file.path}');
}

void genNovel(List<Source> jsNovelSourceList) {
  List<Source> novelSources = [];
  novelSources.addAll(dartNovelSourceList);
  novelSources.addAll(jsNovelSourceList);
  final List<Map<String, dynamic>> jsonList = novelSources
      .map((source) => source.toJson())
      .toList();
  final jsonString = jsonEncode(jsonList);

  final file = File('novel_index.json');
  file.writeAsStringSync(jsonString);

  log('JSON file created: ${file.path}');
}

List<Source> _searchJsSources(Directory dir) {
  List<Source> sourceList = [];
  List<FileSystemEntity> entities = dir.listSync();
  for (FileSystemEntity entity in entities) {
    if (entity is Directory) {
      List<FileSystemEntity> entities = entity.listSync();
      for (FileSystemEntity entity in entities) {
        if (entity is Directory) {
          sourceList.addAll(_searchJsSources(entity));
        } else if (entity is File && entity.path.endsWith('.js')) {
          final defaultSource = Source();
          final match = _jsSourceListPattern.firstMatch(entity.readAsStringSync());
          if (match != null) {
            for (var sourceJson
                in _parseJsSourceList(match.group(1)!, entity.path)) {
              final langs = sourceJson["langs"] as List?;
              Source source = Source.fromJson(sourceJson)
                ..sourceCodeLanguage = 1
                ..appMinVerReq =
                    sourceJson["appMinVerReq"] ?? defaultSource.appMinVerReq
                ..sourceCodeUrl =
                    "https://raw.githubusercontent.com/christianscano/mangayomi-extensions/$branchName/javascript/${sourceJson["pkgPath"] ?? sourceJson["pkgName"]}";
              if (sourceJson["id"] != null) {
                source = source..id = int.tryParse("${sourceJson["id"]}");
              }
              if (langs?.isNotEmpty ?? false) {
                for (var lang in langs!) {
                  final id = sourceJson["ids"]?[lang] as int?;
                  sourceList.add(
                    Source.fromJson(source.toJson())
                      ..lang = lang
                      ..id =
                          id ??
                          'mangayomi-js-"$lang"."${source.name}"'.hashCode,
                  );
                }
              } else {
                sourceList.add(source);
              }
            }
          }
        }
      }
    }
  }
  return sourceList;
}

final _jsSourceListPattern = RegExp(
  r'const\s+mangayomiSources\s*=\s*(\[.*?\]);',
  dotAll: true,
);

List<Map<String, dynamic>> _parseJsSourceList(String sourceListText, String path) {
  try {
    final normalized = _normalizeJsSourceListToJson(sourceListText);
    return List<Map<String, dynamic>>.from(jsonDecode(normalized) as List);
  } on FormatException catch (error) {
    throw FormatException('Failed to parse mangayomiSources in $path: $error');
  }
}

String _normalizeJsSourceListToJson(String sourceListText) {
  return sourceListText
      // JS metadata files often use object-literal keys instead of JSON keys.
      .replaceAllMapped(
        RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)'),
        (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
      )
      .replaceAllMapped(
        RegExp(r',\s*([}\]])'),
        (match) => match.group(1)!,
      );
}
