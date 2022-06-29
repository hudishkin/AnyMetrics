## ЭниМетрикс | [EN] (README.md)

Позволяет создавать запросы к HTTP API или сайт, получать нужные значения из ответа и выводить в виджете.

![Preview](preview.png)

### Правила для получения значений

#### JSON


``` json
{
	"data": {
		"items": ["apple", "google", "facebook"]
	}
}
```

Правило: `data.items.1` выведет: `google`


#### HTML

Используется формат как при `Document.querySelector(selector)`

Пример: `div a.link`

______

[![AppStore](appstore.png)](https://apps.apple.com/us/app/anymetrics/id1609900961)