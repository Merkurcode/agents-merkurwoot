/* global axios */
import ApiClient from './ApiClient';

class ProductBlueprintsAPI extends ApiClient {
  constructor() {
    super('product_blueprints', { accountScoped: true });
  }

  get({ page = 1, per_page = 50, name = undefined, id = undefined } = {}) {
    const params = { page, per_page };
    if (name) params.name = name;
    if (id) params.id = id;
    return axios.get(this.url, { params });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  getByName(name) {
    return axios.get(`${this.url}/by_name`, { params: { name } });
  }

  yamlUpload(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/yaml_upload`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  downloadYamlTemplate() {
    return axios.get(`${this.url}/yaml_template`, { responseType: 'blob' });
  }
}

export default new ProductBlueprintsAPI();
