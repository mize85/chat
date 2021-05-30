import Sortable from "sortablejs";

export const InitSortable = {
  mounted() {
    const callback = list => {
      this.pushEventTo(this.el.dataset.targetId, "sort", { list: list });
    };
    init(this.el, callback);
  }
};

const init = (sortableList, callback) => {
  const listId = sortableList.dataset.listId

  const sortable = new Sortable(sortableList, {
    group: "shared",
    handle: ".cursor-move",
    dragClass: "shadow-xl",
    onSort: evt => {
      let ids = [];
      const nodeList = sortableList.querySelectorAll("[data-sortable-id]");
      for (let i = 0; i < nodeList.length; i++) {
        const idObject = { id: nodeList[i].dataset.sortableId, list_id: listId, sort_order: i };
        ids.push(idObject);
      }
      callback(ids);
    }
  });
};