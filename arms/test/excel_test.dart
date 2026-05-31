import 'package:flutter_test/flutter_test.dart';
import 'package:excel_plus/excel_plus.dart';

void main() {
  test('test excel package api', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    // Write some values
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Test String');
    sheet.cell(CellIndex.indexByString('B1')).value = IntCellValue(123);
    sheet.cell(CellIndex.indexByString('C1')).value = DoubleCellValue(45.67);
    
    // Check reading values
    final a1 = sheet.cell(CellIndex.indexByString('A1')).value;
    final b1 = sheet.cell(CellIndex.indexByString('B1')).value;
    final c1 = sheet.cell(CellIndex.indexByString('C1')).value;
    
    print('A1 type: ${a1.runtimeType}, value: $a1, string: ${a1.toString()}');
    print('B1 type: ${b1.runtimeType}, value: $b1, string: ${b1.toString()}');
    print('C1 type: ${c1.runtimeType}, value: $c1, string: ${c1.toString()}');
    
    expect(a1.toString(), contains('Test String'));
  });
}
