import base64
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADER = (ROOT / 'inspection/Bytecode.h').read_text()
OPCODES = re.findall(r'^\s*(LOP_[A-Z0-9_]+)\s*[,=]', HEADER, re.M)

class Reader:
    def __init__(self, data):
        self.data = data
        self.offset = 0
    def take(self, size):
        out = self.data[self.offset:self.offset+size]
        assert len(out) == size
        self.offset += size
        return out
    def byte(self):
        return self.take(1)[0]
    def varint(self):
        value = shift = 0
        for _ in range(10):
            byte = self.byte()
            value |= (byte & 127) << shift
            if byte < 128:
                return value
            shift += 7
        raise ValueError('Invalid varint')
    def unpack(self, fmt):
        return struct.unpack('<'+fmt, self.take(struct.calcsize('<'+fmt)))[0]

def parse(source):
    data = base64.b64decode(re.search(r'-- Bytecode \(Base64\):\s*\n-- ([A-Za-z0-9+/=]+)', source).group(1))
    reader = Reader(data)
    version = reader.byte()
    types = reader.byte()
    strings = [reader.take(reader.varint()).decode('utf-8', errors='replace') for _ in range(reader.varint())]
    if types == 3:
        while reader.byte():
            reader.varint()
    protos = []
    for _ in range(reader.varint()):
        size = reader.varint() if version >= 12 else None
        start = reader.offset
        stack, params, ups, vararg, flags = [reader.byte() for _ in range(5)]
        reader.take(reader.varint())
        code = [reader.unpack('I') for _ in range(reader.varint())]
        constants = []
        for _ in range(reader.varint()):
            kind = reader.byte()
            if kind == 0: value = None
            elif kind == 1: value = bool(reader.byte())
            elif kind == 2: value = reader.unpack('d')
            elif kind == 3: value = strings[reader.varint()-1]
            elif kind == 4: value = {'Import': reader.unpack('I')}
            elif kind == 5: value = {'Template': [(reader.varint(), -1) for _ in range(reader.varint())]}
            elif kind == 6: value = {'Closure': reader.varint()}
            elif kind == 7: value = {'Vector': [reader.unpack('f') for _ in range(4)]}
            elif kind == 8: value = {'Template': [(reader.varint(), reader.unpack('i')) for _ in range(reader.varint())]}
            elif kind == 9:
                negative = reader.byte()
                value = reader.varint() * (-1 if negative else 1)
            elif kind == 11: value = {'Vector': [reader.unpack('d') for _ in range(4)]}
            else: raise ValueError(f'Unsupported constant {kind}')
            constants.append(value)
        children = [reader.varint() for _ in range(reader.varint())]
        line = reader.varint()
        debugname = reader.varint()
        protos.append({'Stack':stack,'Parameters':params,'Upvalues':ups,'Flags':flags,'Code':code,'Constants':constants,'Children':children,'Line':line,'Name':strings[debugname-1] if debugname else ''})
        if size is None: raise ValueError('Only size-framed bytecode is supported')
        assert reader.offset <= start+size
        reader.offset = start+size
    main = reader.varint()
    return {'Version':version,'Strings':strings,'Protos':protos,'Main':main}

def disassemble(proto):
    code = proto['Code']
    i = 0
    aux_ops = {'GETGLOBAL','SETGLOBAL','GETIMPORT','GETTABLEKS','SETTABLEKS','NAMECALL','NEWTABLE','SETLIST','FORGLOOP','JUMPIFEQ','JUMPIFLE','JUMPIFLT','JUMPIFNOTEQ','JUMPIFNOTLE','JUMPIFNOTLT','LOADKX','FASTCALL2','FASTCALL2K','FASTCALL3','JUMPXEQKNIL','JUMPXEQKB','JUMPXEQKN','JUMPXEQKS','GETUDATAKS','SETUDATAKS','NAMECALLUDATA','CALLFB','CMPPROTO'}
    while i < len(code):
        word = code[i]
        op = OPCODES[(word & 255) * 203 % 256][4:]
        a,b,c = (word>>8)&255,(word>>16)&255,(word>>24)&255
        d = struct.unpack('<h',struct.pack('<H',word>>16))[0]
        aux = code[i+1] if op in aux_ops else None
        yield {'PC':i,'Op':op,'A':a,'B':b,'C':c,'D':d,'Aux':aux}
        i += 2 if aux is not None else 1

if __name__ == '__main__':
    inventory = json.loads((ROOT / 'inspection/inventory.json').read_text())
    for info in inventory['Scripts']:
        if info['Path'] in ['ReplicatedStorage.Shared.Constants','ReplicatedStorage.Shared.Config.PickaxeCatalog','ReplicatedStorage.Shared.Config.Ores','ReplicatedStorage.Shared.Config.Slots']:
            source = (ROOT / 'inspection/scripts' / info['File']).read_text()
            parsed = parse(source)
            (ROOT / 'inspection' / (info['Path'].rsplit('.',1)[1]+'-bytecode.json')).write_text(json.dumps(parsed,indent=2))
            proto = parsed['Protos'][parsed['Main']]
            print(info['Path'], 'protos:',len(parsed['Protos']),'constants:',len(proto['Constants']))
            for instruction in list(disassemble(proto))[:50]:
                if instruction['Op'] in ['LOADK','DUPTABLE']:
                    instruction['Value']=proto['Constants'][instruction['D']]
                if instruction['Op'] in ['SETTABLEKS','GETTABLEKS']:
                    instruction['Key']=proto['Constants'][instruction['Aux']]
                print(instruction)

def recover_static(parsed):
    proto = parsed['Protos'][parsed['Main']]
    constants = proto['Constants']
    registers = {}
    for instruction in disassemble(proto):
        op = instruction['Op']; a=instruction['A'];b=instruction['B'];c=instruction['C'];d=instruction['D'];aux=instruction['Aux']
        if op in ['NOP','PREPVARARGS']: continue
        elif op == 'LOADN': registers[a]=d
        elif op == 'LOADK': registers[a]=constants[d]
        elif op == 'LOADB':
            assert c==0
            registers[a]=bool(b)
        elif op == 'LOADNIL': registers[a]=None
        elif op == 'MOVE': registers[a]=registers[b]
        elif op == 'NEWTABLE': registers[a]={}
        elif op == 'DUPTABLE': registers[a]={constants[key]:constants[value] for key,value in constants[d]['Template'] if value>=0}
        elif op == 'SETTABLEKS': registers[b][constants[aux]]=registers[a]
        elif op == 'GETTABLEKS': registers[a]=registers[b][constants[aux]]
        elif op == 'SETTABLEN': registers[b][c+1]=registers[a]
        elif op == 'GETTABLEN': registers[a]=registers[b][c+1]
        elif op == 'SETLIST':
            assert c>0
            for n in range(c-1): registers[a][aux+n]=registers[b+n]
        elif op in ['ADD','SUB','MUL','DIV','MOD','POW','ADDK','SUBK','MULK','DIVK','MODK','POWK']:
            left=registers[b]; right=constants[c] if op.endswith('K') else registers[c]
            operator=op.rstrip('K')
            registers[a]={'ADD':lambda:left+right,'SUB':lambda:left-right,'MUL':lambda:left*right,'DIV':lambda:left/right,'MOD':lambda:left%right,'POW':lambda:left**right}[operator]()
        elif op == 'RETURN':
            assert b==2
            return registers[a]
        else: raise ValueError('Non-static instruction: '+op)
    raise ValueError('No return')
