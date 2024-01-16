// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:dio/dio.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String storageLocation = (await getApplicationDocumentsDirectory()).path;
  await FastCachedImageConfig.init(subDir: storageLocation, clearCacheAfter: const Duration(days: 15));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
            ),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Search(value: controller.text),
                  ),
                );
              },
              child: const Text('Search'),
            )
          ],
        ),
      ),
    );
  }
}

class Search extends StatefulWidget {
  const Search({super.key, required this.value});
  final String value;

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  late TextEditingController controller;
  List<Manga> mangas = [];

  @override
  void initState() {
    controller = TextEditingController(text: widget.value);
    if (mounted) setState(() {});
    search(widget.value).then((value) {
      mangas = value;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  Future<List<Manga>> search(String query) async {
    var response = await Dio().get('https://mangaonline.biz/search/$query');

    var document = parse(response.data);

    var mangasElement = document.querySelectorAll('#archive-content .item');

    List<Manga> mangas = [];

    for (var element in mangasElement) {
      var name = element.querySelector('.data a')?.text;
      var image = element.querySelector('.poster img')?.attributes['src'];
      var url = element.querySelector('.poster a')?.attributes['href'];

      mangas.add(Manga(name: name, image: image, url: url));
    }

    return mangas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Search'),
        ),
        body: Builder(builder: (context) {
          if (mangas.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width ~/ 180,
              childAspectRatio: 0.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: List.generate(mangas.length, (index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MangaPage(manga: mangas[index]),
                      ),
                    );
                  },
                  child: Card(
                    child: Column(
                      children: [
                        Image.network(mangas[index].image!),
                        Text(mangas[index].name ?? ''),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }));
  }
}

class MangaPage extends StatefulWidget {
  const MangaPage({super.key, required this.manga});

  final Manga manga;

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  List<MangaEpisodes> mangaEpisodes = [];

  List<String> whatchedEpisodes = [];

  @override
  void initState() {
    updateMangaEpisodes(widget.manga.url!);
    updateWatchedEpisodes();
    super.initState();
  }

  Future updateWatchedEpisodes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    whatchedEpisodes = prefs.getStringList('watchedEpsisodes') ?? [];
    if (mounted) setState(() {});
  }

  Future updateMangaEpisodes(String url) async {
    var response = await Dio().get(url);

    var document = parse(response.data);

    List<dom.Element> episodesElement = document.querySelectorAll('.episodios .episodiotitle a');

    mangaEpisodes = episodesElement.map((e) => MangaEpisodes(name: e.text, url: e.attributes['href']!)).toList().reversed.toList();
    if (mounted) setState(() {});
  }

  Future newWatchedEpisode(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    whatchedEpisodes.add(name);
    whatchedEpisodes = whatchedEpisodes.toSet().toList();
    prefs.setStringList('watchedEpsisodes', whatchedEpisodes);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.name ?? ''),
      ),
      body: Builder(builder: (context) {
        if (mangaEpisodes.isEmpty) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemBuilder: (_, index) {
            return ListTile(
              title: Row(
                children: [
                  Text(mangaEpisodes[index].name),
                  if (whatchedEpisodes.contains(mangaEpisodes[index].name))
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(Icons.visibility, color: Colors.red),
                    ),
                ],
              ),
              selected: whatchedEpisodes.contains(mangaEpisodes[index].name),
              selectedColor: Colors.red,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await newWatchedEpisode(mangaEpisodes[index].name);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EpisodePage(episode: mangaEpisodes[index]),
                  ),
                );
              },
            );
          },
          itemCount: mangaEpisodes.length,
        );
      }),
    );
  }
}

class EpisodePage extends StatefulWidget {
  const EpisodePage({super.key, required this.episode});
  final MangaEpisodes episode;

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  List<EpisodeImage> episodeImages = [];

  @override
  void initState() {
    updateEpisodeImages(widget.episode.url);
    super.initState();
  }

  Future updateEpisodeImages(String url) async {
    var response = await Dio().get(url);

    var document = parse(response.data);

    List<dom.Element> content = document.querySelectorAll('.content p img');
    episodeImages = content
        .map((e) => EpisodeImage(
              link: e.attributes['src']!,
              width: onlyNumbers(e.attributes['width']!).toDouble(),
              height: onlyNumbers(e.attributes['height']!).toDouble(),
            ))
        .toList();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.episode.name),
      ),
      body: Builder(builder: (context) {
        if (episodeImages.isEmpty) return const Center(child: CircularProgressIndicator());
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  ...episodeImages.map((e) => ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: FastCachedImage(
                          url: e.link,
                          width: MediaQuery.of(context).size.width,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, image) {
                            return Container(
                              color: Colors.black12,
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      value: image.progressPercentage.value,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class Manga {
  final String? name;
  final String? image;
  final String? url;

  Manga({
    required this.name,
    required this.image,
    required this.url,
  });
}

class MangaEpisodes {
  final String name;
  final String url;

  MangaEpisodes({
    required this.name,
    required this.url,
  });
}

class EpisodeImage {
  final String link;
  final double width;
  final double height;

  EpisodeImage({
    required this.link,
    required this.width,
    required this.height,
  });
}

num onlyNumbers(String number) => num.parse(number.replaceAll(RegExp(r'[^0-9]'), ''));
