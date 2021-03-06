import re
import json
import cssutils
from tinycss2 import *
from bs4 import BeautifulSoup

color = {"1": "Красная", "2": "Тёмно-зелёная", "3": "Синяя", "4": "Голубая", 
         "5": "Коричневая", "6": "Оранжевая", "7": "Фиолетовая", "8": "Жёлтая", "8A": "Жёлтая", "9": "Серая", 
         "10": "Ярко-зелёная", "11": "Бирюзовая", "12": "Серо-голубая", "13": "Светло-бирюзовая", 
         "14": "МЦК", "15": "Розовая", "D1": "Диаметр 1", "D2": "Диаметр 2"}

def get_json_map(file_name):
    data = {}
    id_by_name = {}
    with open(file_name, 'r') as f:
        text = f.read()
        soup = BeautifulSoup (text, 'html.parser')
        for el in soup.find_all('g'):
            if (el.has_attr("id") and el.get("id")[:4] == "line" and el.getText().split() != []):
                id = el.get("id")
                name = ''
                for s in el.getText().split():
                    name += s
                    if s[-1] != '-':
                        name += ' '

                name = name[:-1]
                id_by_name[name] = id
                has_A_B = 0
                if id.find('A'):
                    has_A_B = 3

                data[id] = {}
                data[id]["name"] = name
                data[id]["color"] = color[id[4:id.find('_') - has_A_B + 3]]
                data[id]["neighbours"] = {"span": [], "change": [], "ground_change": []}

                if id[:id.find('_') + 1] + str(int(id[id.find('_') + 1:]) - 1) in data.keys():
                    data[id]["neighbours"]["span"].append(id[:id.find('_') + 1] + str(int(id[id.find('_') + 1:]) - 1))
                    data[id[:id.find('_') + 1] + str(int(id[id.find('_') + 1:]) - 1)]["neighbours"]["span"].append(id)

                if id[:id.find('_') + 1] + str(int(id[id.find('_') + 1:]) + 1) in data.keys():
                    data[id]["neighbours"]["span"].append(id[:id.find('_') + 1] + str(int(id[id.find('_') + 1:]) + 1))

        neigh = str(soup.find_all("style", "type"=="text/css")[1])

        for i in [m.start() for m in re.finditer("{fill:url", neigh)]:
            ind = i + 11
            ind_end = neigh[ind: ind + 30].find("_1_);}")
            conn = neigh[ind: ind + ind_end]
            if (conn.split() == []):
                ind_end = neigh[ind: ind + 30].find("_2_);}")
                conn = neigh[ind: ind + ind_end]

            first = conn[:conn.find('-')]
            second = conn[conn.find('-') + 1:]
            if second == "line8A_4":
                second = "line11_4"

            if first not in data.keys():
                first = first[:-2]
            if second not in data.keys():
                second = second[:-2]

            if len(soup.find_all("path", {"id": first+'-'+second})) and conn.find('D') != -1:
                data[first]["neighbours"]["ground_change"].append(second)
                data[second]["neighbours"]["ground_change"].append(first)
            else:
                data[first]["neighbours"]["change"].append(second)
                data[second]["neighbours"]["change"].append(first)
    return (data, id_by_name)


data, id_by_name = get_json_map("index.html")
with open('map.json', 'w') as f:
    f.write(json.dumps(data, ensure_ascii=False, indent=4, sort_keys=True))

with open('id_by_name.json', 'w') as f:
    f.write(json.dumps(id_by_name, ensure_ascii=False, indent=4, sort_keys=True))

