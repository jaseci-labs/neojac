import json;
import from jaclang.comptime { holds }
import from common.contract { DataError, Host }
import from store.contract { Changed, Row, Store, StoreConflict, Writing }

enum AccessLevel {
    NO_ACCESS = 0,
    READ = 1,
    CONNECT = 2,
    WRITE = 3,
}

obj:pub UnknownType(Exception) {
    has name: str;

    def __str__ -> str;
}

obj Codec {
    def node_type(n: Node) -> str abst;
    def node_data(n: Node) -> dict[str, any] abst;
    def make_node(type_name: str, data: dict[str, any]) -> Node abst;
    def fill_node(n: Node, data: dict[str, any]) abst;

    def edge_type(e: any) -> str abst;
    def edge_data(e: any) -> dict[str, any] abst;
    def connect(type_name: str, a: Node, b: Node, data: dict[str, any]) -> any abst;
    def fill_edge(e: any, data: dict[str, any]) abst;
    def fits(type_name: str, data: dict[str, any]) abst;
    def shape(type_name: str) -> str abst;
    def keeps(type_name: str) -> bool abst;
}

obj NodeType {
    has name: str,
        shape: str,
        holds: Callable[[Node], bool],
        data: Callable[[Node], dict[str, any]],
        make: Callable[[dict[str, any]], Node],
        fill: Callable[[Node, dict[str, any]], None],
        files: Callable[[dict[str, any]], list[str]] | None = None;
}

obj EdgeType {
    has name: str,
        shape: str,
        holds: Callable[[any], bool],
        data: Callable[[any], dict[str, any]],
        connect: Callable[[Node, Node, dict[str, any]], any],
        fill: Callable[[any, dict[str, any]], None],
        fits: Callable[[dict[str, any]], None],
        files: Callable[[dict[str, any]], list[str]] | None = None;
}

glob _node_types: list[NodeType] = [],
     _edge_types: list[EdgeType] = [];
def:pub keep_node[N](name: str) -> bool;
def:pub keep_edge[E](name: str) -> bool;

obj StoreCodec(Codec) {
    def node_type(n: Node) -> str;

    def node_data(n: Node) -> dict[str, any];

    def make_node(type_name: str, data: dict[str, any]) -> Node;

    def fill_node(n: Node, data: dict[str, any]);

    def fill_edge(e: any, data: dict[str, any]);

    def fits(type_name: str, data: dict[str, any]);

    def shape(type_name: str) -> str;

    def keeps(type_name: str) -> bool;

    def edge_type(e: any) -> str;

    def edge_data(e: any) -> dict[str, any];

    def connect(type_name: str, a: Node, b: Node, data: dict[str, any]) -> any;
}

glob _store: dyn Store | None = None,
     _codec: dyn Codec | None = None,
     _grants: dict[str, int] = {},
     _roots: dict[str, Root] = {},
     _user_roots: dict[str, Root] = {},
     _new_roots: dict[str, str] = {},
     _new_shared: list[str] = [],
     _nodes: dict[str, Node] = {},
     _edges: dict[str, any] = {},
     _kept: dict[str, str] = {},
     _versions: dict[str, int] = {},
     _ends: dict[str, tuple[str, str]] = {},
     _edges_at: dict[str, dict[str, bool]] = {},
     _bringing: dict[str, bool] = {},
     _removed: dict[str, bool] = {},
     _mark: list[int] = [0],
     _shapes: dict[str, str] = {},
     _new_shapes: dict[str, str] = {},
     _home: Root = root;

glob TRIES: int = 4;
def:pub grant(n: Node, level: AccessLevel = AccessLevel.READ);
def keeper -> tuple[dyn Store, dyn Codec];
def unmade(r: Row, why: str) -> DataError;
def take_node(r: Row) -> Node;
def bring_nodes(ids: list[str]);
def take_edge(r: Row) -> any;
def forget(id: str);
def edges_here(n: Node) -> dict[str, bool];
def bring_edges(n: Node);
def reach(n: Node);
def node_kept(id: str) -> Node | None;
def:pub jobj(name: str) -> any;
def find_kept(name: str) -> any;
def:pub remove(n: Node);
def:pub allroots -> list[Root];
def bring_roots;
def counted(counts: dict[str, int]) -> str;
def:pub graph_open(store: dyn Store, codec: dyn Codec, host: dyn Host);
def:pub root_for(user: str) -> Root;
def find_root(user: str);
def enter_caller(user: str, call: int);
def:pub current_caller -> str;

obj Turns {
    def take(work: Callable[[], None]) abst;
    def rest abst;
    def wake abst;
    def waits -> bool abst;
}

obj Alone(Turns) {
    def take(work: Callable[[], None]);

    def rest;

    def wake;

    def waits -> bool;
}

obj:pub Flight {
    has call: int = 0,
        epoch: int = 0,
        within: bool = False;
}

glob _turns: dyn Turns = Alone(),
     _running: dict[int, int] = {},
     _numbered: int = 0,
     _settling: bool = False,
     _epoch: int = 0,
     _refused: list[str] = [];
def:pub store_in_turn(turns: dyn Turns);
def in_turn(work: Callable[[], None]);
def refusal -> StoreConflict;
def begun(user: str) -> Flight;
def pass_gate(f: Flight);
def leave(f: Flight);
def refuse(e: StoreConflict);
def settle;
def keep(f: Flight, lost: list[StoreConflict]);
def rejoin(f: Flight);
def:pub kept_call(user: str, work: Callable[[], any]) -> any;
def:pub stream_begun(user: str) -> Flight;
def:pub stream_paused(f: Flight);
def:pub stream_resumed(f: Flight) -> StoreConflict | None;
def resume(f: Flight, lost: list[StoreConflict]);
def:pub stream_kept(f: Flight);
def:pub commit;
def commit_now(lost: list[StoreConflict]);
def:pub sweep -> int;
def:pub held_files -> list[str];
def files_held -> dict[str, bool];
def sweep_kept -> int;
def node_text(n: Node, nid: str) -> str;
def root_ids -> dict[str, bool];
def write_changes;
def note_shape(w: Writing, kind: str);
def fields_changed(nid: str) -> bool;
def edge_changed(eid: str, seen_at: dict[str, dict[str, bool]]) -> bool;
def held_here(nid: str, seen_at: dict[str, dict[str, bool]]) -> dict[str, bool];
def edges_changed(nid: str) -> bool;
def node_changed(nid: str) -> bool;
def take_in;
def adopt_shared;
def put_back;
