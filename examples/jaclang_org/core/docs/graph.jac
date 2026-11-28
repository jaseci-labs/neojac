import os;
import re;

glob SITE_ORIGIN: str = os.environ.get("JAC_SITE_ORIGIN", "https://www.jaclang.org"),
     INDEX_FILES: list[str] = ["index.md", "SKILL.md"];

node PublicNode {}

edge PublicEdge: PublicNode --> PublicNode {}

node DocsHub(PublicNode) {
    has built_at: str = "";
}

node DocContainer(PublicNode) {}

node DocVersion(DocContainer) {
    has label: str = "",
        version: str = "",
        fetched_at: str = "",
        fingerprint: str = "",
        pages: int = 0;

    def tree -> list[TreeNode];
    def reading_order -> list[DocPage];
}

node DocSection(DocContainer) {
    has title: str = "";
}

node DocPage(PublicNode) {
    has path: str = "",
        title: str = "",
        description: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];
}

edge HasHub(PublicEdge): Node --> DocsHub {}

edge HasVersion(PublicEdge): DocsHub --> DocVersion {}

edge Contains(PublicEdge): DocContainer --> DocSection | DocPage {}

edge NextPage(PublicEdge): DocPage --> DocPage {}

walker trace_sections {
    has titles: list[str] = [];

    can leave_page with DocPage entry;
    can climb with DocSection entry;
}

def sections_of(page: DocPage) -> list[str];

def _teardown_version(v: DocVersion);

def _teardown_hub(hub: DocsHub);

def _sweep_stale(keep: DocsHub);

def _series_of(label: str) -> tuple[int, int] | None;

def _latest_label(labels: list[str]) -> str;

def _version(wanted: str) -> list[DocVersion];

def slugify(t: str) -> str;

def _pretty(name: str) -> str;

def toc_of(text: str) -> list[TocEntry];
def page_name(file: str) -> str;
def page_path(rel: str) -> str;

def route_of(version: str, rel: str) -> str;

def rewrite_href(href: str, version: str, cur_dir: str) -> str;

def _get_hub -> DocsHub | None;

def _version_list -> list[VersionInfo];

walker place_page {
    has trail: list[str] = [],
        path: str = "",
        title: str = "",
        description: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];

    can place with DocContainer entry;
}

walker collect_tree {
    has folded: dict[str, TreeNode] = {},
        folded_seq: dict[str, list[DocPage]] = {},
        tree: list[TreeNode] = [],
        seq: list[DocPage] = [];

    can scan with DocContainer entry;
    can fold_page with DocPage exit;
    can fold_section with DocSection exit;
    can fold_version with DocVersion exit;
    def gather(container: DocContainer) -> tuple[list[TreeNode], list[DocPage]];
}

def:pub docs_status -> DocsStatus;

def:pub doc_tree(version: str = "latest") -> DocTree | None;
def _llms_sections(
    nodes: list[TreeNode], trail: list[str], by_path: dict[str, DocPage], lines: list[str]
);

def _llms_entry(pg: TreeNode, by_path: dict[str, DocPage]) -> str;

def _first_prose(md_lines: list[str]) -> str;

glob LLMS_HEADER: str = ("# neojac\n"
    "\n"
    "> neojac is a native-first implementation of the Jac language. Its"
    " compiler is written in Jac and compiles itself, and it compiles a Jac"
    " program, with neojac's own runtime, into one native executable through"
    " LLVM. One download carries everything a build needs: the compiler, the"
    " runtime, and CPython, Node, Clang and Rust, which run under the"
    " `neojac` command too.\n"
    "\n"
    "neojac defines the Jac language it compiles. It is not jaseci's `jac`"
    " with another backend: some forms `jac` accepts are errors here, so read"
    " the language pages rather than assuming what `jac` or Python does.\n"
    "\n"
    "Offline access: the same pages ship with every release and"
    " `neojac docs` prints them, for exactly the version installed:"
    " `neojac docs <word>` looks up a keyword, a grammar rule, a diagnostic"
    " code or a command, and `neojac docs search <text>` searches every page."
    " `neojac skills` lists playbooks for tasks, and `neojac skills <name>`"
    " prints one.\n");

@restspec(method=HTTPMethod.GET, path="/llms.txt", produces="text/plain", envelope=False)
def:pub llms_txt -> str;

walker find_page {
    has asked: list[str] = [],
        page: DocPage | None = None,
        reach: int = -1;

    can enter with DocContainer entry;
    can weigh with DocPage entry;
}

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        missing: bool = False,
        reports: list[DocPageView | None] = [];

    can start with Root entry;
    can find with DocVersion entry;
    can deliver with DocPage entry;
}
