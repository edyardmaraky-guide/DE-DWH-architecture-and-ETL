import pandas as pd
import os
import sys

def check_dependencies():
    """Проверяет наличие необходимых библиотек"""
    try:
        import openpyxl
        print("✅ openpyxl установлен")
        return True
    except ImportError:
        print("❌ openpyxl не установлен. Установите: pip install openpyxl")
        return False

def excel_to_csvs(excel_file, output_dir="."):
    """
    Разделяет страницы Excel на отдельные CSV файлы
    
    Args:
        excel_file: путь к Excel файлу
        output_dir: папка для сохранения CSV (по умолчанию текущая)
    """
    
    if not check_dependencies():
        return
    
    # Проверяем существование файла
    if not os.path.exists(excel_file):
        print(f"❌ Файл {excel_file} не найден!")
        return
    
    # Создаем папку для выходных файлов, если её нет
    os.makedirs(output_dir, exist_ok=True)
    
    # Словарь: "Имя страницы" -> "имя CSV файла"
    sheets_to_export = {
        "Customers": "customers.csv",
        "Product": "products.csv",
        "Sales": "sales.csv"
    }
    
    print(f"\n📂 Читаем файл: {excel_file}")
    print("=" * 50)
    
    # Получаем список всех страниц в файле
    try:
        xl = pd.ExcelFile(excel_file)
        available_sheets = xl.sheet_names
        print(f"Доступные страницы: {available_sheets}")
    except Exception as e:
        print(f"❌ Не удалось прочитать файл Excel: {e}")
        return
    
    success_count = 0
    for sheet_name, csv_name in sheets_to_export.items():
        try:
            # Проверяем, есть ли такая страница
            if sheet_name not in available_sheets:
                print(f"⚠️ Страница '{sheet_name}' не найдена в файле. Пропускаем.")
                continue
            
            # Читаем страницу
            print(f"\n📄 Читаем страницу: {sheet_name}...")
            df = pd.read_excel(excel_file, sheet_name=sheet_name)
            
            # Полный путь к CSV
            csv_path = os.path.join(output_dir, csv_name)
            
            # Сохраняем в CSV
            df.to_csv(csv_path, index=False, encoding='utf-8')
            
            print(f"   ✅ Сохранено: {csv_path}")
            print(f"   📊 Строк: {len(df)}, Колонок: {len(df.columns)}")
            print(f"   📋 Колонки: {list(df.columns)}")
            
            success_count += 1
            
        except Exception as e:
            print(f"❌ Ошибка при обработке страницы '{sheet_name}': {e}")
    
    print("\n" + "=" * 50)
    print(f"✅ Готово! Успешно обработано {success_count} из {len(sheets_to_export)} страниц")
    
    if success_count > 0:
        print(f"\nCSV файлы сохранены в папке: {os.path.abspath(output_dir)}")

def show_first_rows(csv_file, n=5):
    """Показывает первые n строк CSV файла"""
    try:
        df = pd.read_csv(csv_file)
        print(f"\n📊 Первые {n} строк из {os.path.basename(csv_file)}:")
        print(df.head(n))
        print(f"   Всего строк: {len(df)}")
    except Exception as e:
        print(f"❌ Не удалось прочитать {csv_file}: {e}")

if __name__ == "__main__":
    # Настройки
    excel_file = "./raw_data/generate_csv/Calculated Field Examples.xlsx"  # имя вашего файла
    output_folder = "."  # папка для CSV файлов
    
    # Запускаем конвертацию
    excel_to_csvs(excel_file, output_folder)
    
    # Если конвертация прошла успешно, покажем первые строки
    if os.path.exists(output_folder):
        print("\n" + "=" * 50)
        print("ПРЕДПРОСМОТР СОЗДАННЫХ ФАЙЛОВ:")
        
        for csv_file in ["customers.csv", "products.csv", "sales.csv"]:
            csv_path = os.path.join(output_folder, csv_file)
            if os.path.exists(csv_path):
                show_first_rows(csv_path)