import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'transaction.dart';                     // Import model Transaction

// --- PERUBAHAN 1: Ubah 'main' menjadi async untuk inisialisasi Hive ---
Future<void> main() async {
  // Pastikan Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Hive
  await Hive.initFlutter();

  // Daftarkan Adapter yang sudah di-generate
  Hive.registerAdapter(TransactionAdapter());

  // Buka box untuk menyimpan transaksi
  await Hive.openBox<Transaction>('transactions');

  runApp(const AntiBoncosApp());
}

class AntiBoncosApp extends StatelessWidget {
  const AntiBoncosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anti-Boncos',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- PERUBAHAN 2: Ganti List dengan Box Hive ---
  // Kita tidak lagi butuh List sementara, kita langsung pakai Box dari Hive.
  final Box<Transaction> transactionBox = Hive.box<Transaction>('transactions');

  // --- PERUBAHAN 3: Fungsi 'add' dan 'delete' diubah untuk Hive ---
  void _addTransaction(String type, String description, double amount) {
    // Buat objek Transaction baru
    final newTransaction = Transaction()
      ..type = type
      ..description = description
      ..amount = amount
      ..createdAt = DateTime.now(); // Simpan tanggal pembuatan

    // Masukkan objek ke dalam Box Hive
    transactionBox.add(newTransaction);
  }

  void _deleteTransaction(int index) {
    // Hapus data dari Box Hive berdasarkan index-nya
    transactionBox.deleteAt(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet Anti-Boncos 💸'),
      ),
      // --- PERUBAHAN 4: Gunakan ValueListenableBuilder ---
      // Widget ini akan 'mendengarkan' perubahan di box
      // dan otomatis membangun ulang UI jika ada data baru/dihapus.
      body: ValueListenableBuilder(
        valueListenable: transactionBox.listenable(),
        builder: (context, Box<Transaction> box, _) {
          // Ambil semua data dari box dan jadikan List
          final transactions = box.values.toList().cast<Transaction>();

          // Kalkulasi total langsung dari data di dalam box
          double totalPemasukan = transactions
              .where((tx) => tx.type == 'Pemasukan')
              .fold(0.0, (sum, item) => sum + item.amount);
          double totalPengeluaran = transactions
              .where((tx) => tx.type == 'Pengeluaran')
              .fold(0.0, (sum, item) => sum + item.amount);
          double sisaSaldo = totalPemasukan - totalPengeluaran;

          return Column(
            children: [
              _buildSummaryCard(sisaSaldo, totalPemasukan, totalPengeluaran),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Riwayat Transaksi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                     'Geser untuk hapus',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('Belum ada transaksi.'))
                    : _buildTransactionList(transactions), // Kirim list transaksi ke widget
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- PERUBAHAN 5: Widget-widget sekarang menerima data sebagai parameter ---
  Widget _buildSummaryCard(double sisaSaldo, double totalPemasukan, double totalPengeluaran) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Sisa Saldo',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              'Rp ${sisaSaldo.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                    'Pemasukan', 'Rp ${totalPemasukan.toStringAsFixed(0)}', Icons.arrow_downward, Colors.green),
                _buildSummaryItem(
                    'Pengeluaran', 'Rp ${totalPengeluaran.toStringAsFixed(0)}', Icons.arrow_upward, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

 Widget _buildTransactionList(List<Transaction> transactions) {
  return ListView.builder(
    itemCount: transactions.length,
    itemBuilder: (context, index) {
      final tx = transactions[index];
      final isIncome = tx.type == 'Pemasukan';

      return Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.endToStart,
        
        // --- INI BAGIAN UTAMA YANG DIUBAH ---
        onDismissed: (direction) {
          // 1. Simpan data dan index-nya sebelum benar-benar dihapus
          final deletedTransaction = transactions[index];
          final deletedIndex = index;

          // 2. Hapus data dari database (ini akan membuat UI update)
          _deleteTransaction(index);

          // 3. Hapus SnackBar lama jika ada, agar tidak menumpuk
          ScaffoldMessenger.of(context).clearSnackBars();

          // 4. Tampilkan SnackBar baru dengan tombol Aksi "Urungkan"
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${deletedTransaction.description} telah dihapus.'),
              duration: const Duration(seconds: 4), // Beri waktu lebih lama
              action: SnackBarAction(
                label: 'URUNGKAN',
                onPressed: () {
                  // 5. Jika 'URUNGKAN' ditekan, panggil fungsi untuk mengembalikan data
                  // Kita buat fungsi baru untuk ini agar rapi
                  _reinsertTransaction(deletedIndex, deletedTransaction);
                },
              ),
            ),
          );
        },
        // ------------------------------------------

        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: ListTile(
            leading: Icon(
              isIncome ? Icons.account_balance_wallet : Icons.shopping_cart,
              color: isIncome ? Colors.green : Colors.orange,
            ),
            title: Text(tx.description),
            trailing: Text(
              '${isIncome ? '+' : '-'} Rp ${tx.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    },
  );
}

// --- TAMBAHKAN FUNGSI BARU INI DI DALAM _HomeScreenState ---
void _reinsertTransaction(int index, Transaction transaction) {
  // Karena Hive Box tidak punya method 'insertAt', kita lakukan trik ini:
  // 1. Ubah semua data di box menjadi List
  final list = transactionBox.values.toList();

  // 2. Masukkan data yang dihapus ke posisi semula di dalam List
  list.insert(index, transaction);

  // 3. Hapus semua data di box (clear)
  transactionBox.clear().then((_) {
    // 4. Masukkan kembali semua data dari List yang sudah diupdate
    transactionBox.addAll(list);
  });
}
  void _showAddTransactionDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String transactionType = 'Pengeluaran';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Transaksi Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Deskripsi'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Uang Masuk'),
                        value: 'Pemasukan',
                        groupValue: transactionType,
                        onChanged: (value) => setDialogState(() => transactionType = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Uang Keluar'),
                        value: 'Pengeluaran',
                        groupValue: transactionType,
                        onChanged: (value) => setDialogState(() => transactionType = value!),
                      ),
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton(
                  child: const Text('Tambah'),
                  onPressed: () {
                    final description = descriptionController.text;
                    final amount = double.tryParse(amountController.text);

                    if (description.isEmpty || amount == null || amount <= 0) {
                      return;
                    }
                    _addTransaction(transactionType, description, amount);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}