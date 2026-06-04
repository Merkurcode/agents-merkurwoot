/* global axios */
import ApiClient from './ApiClient';

class ScheduleBlocksAPI extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  getForAgent(agentId) {
    return axios.get(`${this.url}/${agentId}/schedule_blocks`);
  }

  create(agentId, block) {
    return axios.post(`${this.url}/${agentId}/schedule_blocks`, {
      schedule_block: block,
    });
  }

  update(agentId, blockId, block) {
    return axios.patch(`${this.url}/${agentId}/schedule_blocks/${blockId}`, {
      schedule_block: block,
    });
  }

  destroy(agentId, blockId) {
    return axios.delete(`${this.url}/${agentId}/schedule_blocks/${blockId}`);
  }
}

export default new ScheduleBlocksAPI();
