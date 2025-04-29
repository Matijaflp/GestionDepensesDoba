import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MonApp());
}

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Dépenses',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AccueilPage(),
    );
  }
}

class Mois {
  String nom;
  List<Map<String, dynamic>> transactions;
  double solde;

  Mois({required this.nom, List<Map<String, dynamic>>? transactions, this.solde = 0})
      : transactions = transactions ?? [];

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'transactions': transactions,
        'solde': solde,
      };

  static Mois fromJson(Map<String, dynamic> json) {
    return Mois(
      nom: json['nom'],
      transactions: List<Map<String, dynamic>>.from(json['transactions'].map((t) => Map<String, dynamic>.from(t))),
      solde: json['solde'],
    );
  }
}

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _commentaireController = TextEditingController();
  final TextEditingController _categorieController = TextEditingController();

  List<Mois> historiqueMois = [];
  late Mois moisActuel;

  @override
  void initState() {
    super.initState();
    moisActuel = Mois(nom: 'Mois Actuel');
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    final prefs = await SharedPreferences.getInstance();
    final moisData = prefs.getString('moisActuel');
    final historiqueData = prefs.getString('historiqueMois');

    if (moisData != null) {
      moisActuel = Mois.fromJson(jsonDecode(moisData));
    }

    if (historiqueData != null) {
      historiqueMois = List<Mois>.from(
          jsonDecode(historiqueData).map((e) => Mois.fromJson(Map<String, dynamic>.from(e))));
    }

    setState(() {});
  }

  Future<void> _sauvegarderDonnees() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moisActuel', jsonEncode(moisActuel.toJson()));
    await prefs.setString('historiqueMois', jsonEncode(historiqueMois.map((m) => m.toJson()).toList()));
  }

  void _ajouterTransaction(String type) {
    final montant = double.tryParse(_montantController.text);
    final commentaire = _commentaireController.text;
    final categorie = _categorieController.text;

    if (montant != null) {
      setState(() {
        moisActuel.transactions.add({
          'type': type,
          'montant': montant,
          'commentaire': (categorie.isNotEmpty ? "$categorie: " : '') + commentaire,
        });

        if (type == 'Dépense') {
          moisActuel.solde -= montant;
        } else {
          moisActuel.solde += montant;
        }

        _montantController.clear();
        _commentaireController.clear();
        _categorieController.clear();
      });
      _sauvegarderDonnees();
    }
  }

  void _modifierTransaction(int index) {
    final t = moisActuel.transactions[index];
    _montantController.text = t['montant'].toString();
    _commentaireController.text = t['commentaire']?.split(': ')?.last ?? '';
    _categorieController.text = t['commentaire']?.contains(':') == true
        ? t['commentaire'].split(':').first
        : '';

    String type = t['type'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier la Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant'),
              ),
              TextField(
                controller: _categorieController,
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
              TextField(
                controller: _commentaireController,
                decoration: const InputDecoration(labelText: 'Commentaire'),
              ),
              DropdownButton<String>(
                value: type,
                onChanged: (newValue) {
                  setState(() {
                    type = newValue!;
                  });
                },
                items: ['Entrée', 'Dépense'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final nouveauMontant = double.tryParse(_montantController.text);
                if (nouveauMontant != null) {
                  setState(() {
                    double ancienMontant = t['montant'];
                    String ancienType = t['type'];

                    if (ancienType == 'Entrée') {
                      moisActuel.solde -= ancienMontant;
                    } else {
                      moisActuel.solde += ancienMontant;
                    }

                    if (type == 'Entrée') {
                      moisActuel.solde += nouveauMontant;
                    } else {
                      moisActuel.solde -= nouveauMontant;
                    }

                    moisActuel.transactions[index] = {
                      'type': type,
                      'montant': nouveauMontant,
                      'commentaire': (_categorieController.text.isNotEmpty
                              ? "${_categorieController.text}: "
                              : '') +
                          _commentaireController.text,
                    };
                  });
                  _sauvegarderDonnees();
                  Navigator.pop(context);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  void _supprimerTransaction(int index) {
    setState(() {
      var t = moisActuel.transactions[index];
      if (t['type'] == 'Entrée') {
        moisActuel.solde -= t['montant'];
      } else {
        moisActuel.solde += t['montant'];
      }
      moisActuel.transactions.removeAt(index);
    });
    _sauvegarderDonnees();
  }

  void _modifierNomMois() {
    TextEditingController nomController = TextEditingController(text: moisActuel.nom);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le nom du Mois'),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(labelText: 'Nom du Mois'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                moisActuel.nom = nomController.text;
              });
              _sauvegarderDonnees();
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          )
        ],
      ),
    );
  }

  void _nouveauMois() {
    TextEditingController nomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un nouveau Mois'),
        content: TextField(
          controller: nomController,
          decoration: const InputDecoration(labelText: 'Nom du nouveau mois'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                historiqueMois.add(moisActuel);
                moisActuel = Mois(
                  nom: nomController.text,
                  transactions: [
                    if (historiqueMois.isNotEmpty && historiqueMois.last.solde != 0)
                      {
                        'type': historiqueMois.last.solde >= 0 ? 'Entrée' : 'Dépense',
                        'montant': historiqueMois.last.solde.abs(),
                        'commentaire': 'Report mois précédent',
                      }
                  ],
                  solde: historiqueMois.last.solde,
                );
              });
              _sauvegarderDonnees();
              Navigator.pop(context);
            },
            child: const Text('Créer'),
          )
        ],
      ),
    );
  }

  void _ouvrirHistorique() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoriquePage(historiqueMois: historiqueMois),
      ),
    ).then((_) => _chargerDonnees());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(moisActuel.nom),
        actions: [
          IconButton(
            onPressed: _ouvrirHistorique,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: _modifierNomMois,
            icon: const Icon(Icons.edit),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant'),
            ),
            TextField(
              controller: _categorieController,
              decoration: const InputDecoration(labelText: 'Catégorie (optionnel)'),
            ),
            TextField(
              controller: _commentaireController,
              decoration: const InputDecoration(labelText: 'Commentaire (optionnel)'),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _ajouterTransaction('Dépense'),
                  child: const Text('Dépense'),
                ),
                ElevatedButton(
                  onPressed: () => _ajouterTransaction('Entrée'),
                  child: const Text('Entrée'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Solde : ${moisActuel.solde.toStringAsFixed(2)} CHF',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: moisActuel.transactions.length,
                itemBuilder: (context, index) {
                  final t = moisActuel.transactions[index];
                  return ListTile(
                    leading: Icon(
                      t['type'] == 'Entrée'
                          ? Icons.add_circle
                          : Icons.remove_circle,
                      color: t['type'] == 'Entrée' ? Colors.green : Colors.red,
                    ),
                    title: Text('${t['montant']} - ${t['commentaire']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _modifierTransaction(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _supprimerTransaction(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _nouveauMois,
              child: const Text('Nouveau Mois'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoriquePage extends StatelessWidget {
  final List<Mois> historiqueMois;

  const HistoriquePage({super.key, required this.historiqueMois});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Mois'),
      ),
      body: ListView.builder(
        itemCount: historiqueMois.length,
        itemBuilder: (context, index) {
          final mois = historiqueMois[index];
          return ListTile(
            title: Text(mois.nom),
            subtitle: Text('Solde: ${mois.solde.toStringAsFixed(2)} CHF'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccueilPage(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
