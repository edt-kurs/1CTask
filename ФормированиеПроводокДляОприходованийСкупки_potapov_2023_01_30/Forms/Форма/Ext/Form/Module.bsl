﻿
&НаКлиенте
Процедура КомандаСоздатьНужныеПроводки(Команда)
	СоздатьПроводкиНаСервере();
	Сообщение = Новый СообщениеПользователю;
	Сообщение.Текст = "Обработка по созданию ручных проводок для документов ОриходованиеТМЦ завершена!";
	Сообщение.Сообщить();
КонецПроцедуры


&НаСервере
Процедура СоздатьПроводкиНаСервере()
	Если НЕ ЭтаФорма.ДокументСсылка.Пустая() Тогда
		СоздатьПроводкиДляДокумента(ЭтаФорма.ДокументСсылка);
	ИначеЕсли ЗначениеЗаполнено(ЭтаФорма.ПериодОбработки.ДатаНачала) И ЗначениеЗаполнено(ЭтаФорма.ПериодОбработки.ДатаОкончания) Тогда
		Запрос = Новый Запрос;
		Запрос.УстановитьПараметр("НачалоПериода",ЭтаФорма.ПериодОбработки.ДатаНачала); 
		Запрос.УстановитьПараметр("КонецПериода",ЭтаФорма.ПериодОбработки.ДатаОкончания);
		Запрос.Текст = 
		"ВЫБРАТЬ
		|	ОприходованиеТоваров.Ссылка КАК ДокументСсылка
		|ИЗ
		|	Документ.ОприходованиеТоваров КАК ОприходованиеТоваров
		|ГДЕ
		|	ОприходованиеТоваров.Проведен
		|	И ОприходованиеТоваров.Дата МЕЖДУ &НачалоПериода И &КонецПериода
		|	И НЕ ОприходованиеТоваров.ПометкаУдаления
		|
		|УПОРЯДОЧИТЬ ПО
		|	ОприходованиеТоваров.Дата";
		ТЗ = Запрос.Выполнить().Выгрузить();
		Для Каждого СтрокаТЗ ИЗ ТЗ Цикл
			СоздатьПроводкиДляДокумента(СтрокаТЗ.ДокументСсылка);
		КонецЦикла;			
	КонецЕсли;
КонецПроцедуры

&НаСервере
Процедура СоздатьПроводкиДляДокумента(ОприходованиеСсылка)
	Если ОприходованиеСсылка.Пустая() Тогда
		Возврат;
	КонецЕсли;
	
	ОприходованиеОбъект = ОприходованиеСсылка.ПолучитьОбъект();
	ОприходованиеОбъект.РучнаяКорректировка = Ложь;
    ОприходованиеОбъект.Записать(РежимЗаписиДокумента.Запись);
	ОприходованиеОбъект.РучнаяКорректировка = Истина;
	Попытка
		ОприходованиеОбъект.Записать(РежимЗаписиДокумента.Запись);
	Исключение
		Сообщение = Новый СообщениеПользователю;
		Сообщение.Текст = "" + ОписаниеОшибки();
		Сообщение.Сообщить();
		Возврат;
	КонецПопытки;
	
	СпособОценкиМПЗ         = УчетнаяПолитика.СпособОценкиМПЗ(ОприходованиеСсылка.Организация, ОприходованиеСсылка.Дата);
	ВедетсяУчетПоПартиям    = СпособОценкиМПЗ <> Перечисления.СпособыОценки.ПоСредней;
	
	ОприходованиеОбъект = Документы.ОприходованиеТоваров.СоздатьДокумент();
	
	//движения по бухне
	Движения = РегистрыБухгалтерии.Хозрасчетный.СоздатьНаборЗаписей();
	Движения.Отбор.Регистратор.Установить(ОприходованиеСсылка);
	Движения.Прочитать();
	Движения.Очистить();
	
	Для каждого СтрокаТаблицы Из ОприходованиеСсылка.Товары Цикл

		Проводка = Движения.Добавить();

		Проводка.Регистратор = ОприходованиеСсылка;
		Проводка.Период      = ОприходованиеСсылка.Дата;
		Проводка.Организация = ОприходованиеСсылка.Организация;
		Проводка.Содержание  = "Оприходование излишков товаров";//СокрЛП(СтрокаТаблицы.Содержание);

		Проводка.СчетДт = СтрокаТаблицы.СчетУчета;
		БухгалтерскийУчет.УстановитьСубконто(Проводка.СчетДт, Проводка.СубконтоДт, "Номенклатура", СтрокаТаблицы.Номенклатура);
		БухгалтерскийУчет.УстановитьСубконто(Проводка.СчетДт, Проводка.СубконтоДт, "Склады", ОприходованиеСсылка.Склад);
		Если ВедетсяУчетПоПартиям Тогда
			БухгалтерскийУчет.УстановитьСубконто(Проводка.СчетДт, Проводка.СубконтоДт, "Партии", ОприходованиеСсылка);
		КонецЕсли;
		БухгалтерскийУчет.УстановитьСубконто(Проводка.СчетДт, Проводка.СубконтоДт, "СтавкиНДС", СтрокаТаблицы.СтавкаНДСВРознице);
		
		СвойстваСчетаДт = БухгалтерскийУчетВызовСервераПовтИсп.ПолучитьСвойстваСчета(Проводка.СчетДт);
		
		Если СвойстваСчетаДт.УчетПоПодразделениям Тогда
			Проводка.ПодразделениеДт = ОприходованиеСсылка.ПодразделениеОрганизации;
		КонецЕсли;
		
		Если СвойстваСчетаДт.Количественный Тогда
			Проводка.КоличествоДт = СтрокаТаблицы.Количество;
		КонецЕсли;
		
		Проводка.СчетКт = ПланыСчетов.Хозрасчетный.КассаОрганизации;
		СвойстваСчетаКт = БухгалтерскийУчетВызовСервераПовтИсп.ПолучитьСвойстваСчета(Проводка.СчетКт);
		
		Для НомерСубконто = 1 По СвойстваСчетаКт.КоличествоСубконто Цикл
			Если СвойстваСчетаКт["ВидСубконто" + Строка(НомерСубконто)+ "ТипЗначения"].СодержитТип(Тип("СправочникСсылка.СтатьиДвиженияДенежныхСредств")) Тогда
				БухгалтерскийУчет.УстановитьСубконто(Проводка.СчетКт, Проводка.СубконтоКт,
				СвойстваСчетаКт["ВидСубконто" + Строка(НомерСубконто)], Справочники.СтатьиДвиженияДенежныхСредств.ОплатаПоставщику);
			КонецЕсли;
		КонецЦикла;
		//
		//Если СвойстваСчетаКт.УчетПоПодразделениям Тогда
		//	Проводка.ПодразделениеКт = СтрокаТаблицы.ПодразделениеДоходов;
		//КонецЕсли;
		//
		Проводка.Сумма = СтрокаТаблицы.Сумма; 
		Проводка.СуммаНУДт = СтрокаТаблицы.Сумма;
		Проводка.СуммаНУКт = СтрокаТаблицы.Сумма;
		
		НалоговыйУчет.ЗаполнитьНалоговыеСуммыПроводки(Проводка.СуммаНУДт, Проводка.СуммаНУКт,Проводка.СуммаПРДт,Проводка.СуммаПРКт,
			Проводка.СуммаВРДт, Проводка.СуммаВРКт,Проводка);
		
	КонецЦикла;

	Движения.Записать(Истина);
    // sr74 potapov 30.01.2023 начало
	////Движения по книге доходов и расходов
	//ДвиженияКнига = РегистрыНакопления.КнигаУчетаДоходовИРасходов.СоздатьНаборЗаписей();
	//ДвиженияКнига.Отбор.Регистратор.Установить(ОприходованиеСсылка);
	//ДвиженияКнига.Прочитать();
	//ДвиженияКнига.Очистить();
	//
	//ДвижениеКниги = ДвиженияКнига.Добавить();
	//ДвижениеКниги.Регистратор = ОприходованиеСсылка;
	//ДвижениеКниги.Период = ОприходованиеСсылка.Дата;
	//ДвижениеКниги.Активность = Истина;
	////ижениеКниги.СтрокаДокумента = 1;
	//ДвижениеКниги.Содержание = "Скупка товара";
	//ДвижениеКниги.Графа5 = 0;
	//ДвижениеКниги.Графа7 = 0;
	//ДвижениеКниги.Графа6 = ОприходованиеСсылка.СуммаДокумента;
	//ДвижениеКниги.РеквизитыПервичногоДокумента = УчетУСН.РеквизитыПервичногоДокументаДляКУДиР(ОприходованиеСсылка.Дата, ОприходованиеСсылка.Номер, ОприходованиеСсылка.Дата);  
	//ДвижениеКниги.НДС = 20;
	//ДвиженияКнига.Записать(Истина);
	// sr74 potapov 30.01.2023 конец

	// sr74 potapov 30.01.2023 начало
	//Движения по РасходыПриУСН
	//ДвиженияРасходыУСН = РегистрыНакопления.РасходыПриУСН.СоздатьНаборЗаписей();
	//ДвиженияРасходыУСН.Отбор.Регистратор.Установить(ОприходованиеСсылка);
	//ДвиженияРасходыУСН.Прочитать();
	//
	////ДвиженияРасходыУСН.Очистить();
	//
	//Для каждого ДвижениеР Из ДвиженияРасходыУСН Цикл
	//	ДвижениеР.ОтражениеВУСН = Перечисления.ОтражениеВУСН.Принимаются;
	//КонецЦикла;
	//ДвиженияРасходыУСН.Записать(Истина);
	// sr74 potapov 30.01.2023 конец	
	
КонецПроцедуры
